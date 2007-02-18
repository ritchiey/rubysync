#!/usr/bin/env ruby -w
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
#
# This file is part of RubySync.
# 
# RubySync is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
# 
# RubySync is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with RubySync; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

module RubySync
  module Connectors
    
    class BaseConnector
      
      include RubySync::Utilities
      
      attr_accessor :once_only, :name, :is_vault
      
      
      def initialize options={}
        once_only = false
        options.each do |key, value|
          send("#{key}=", value) if respond_to? "#{key}="
        end
        self.name = options[:name]
        self.is_vault = options[:is_vault]
        if is_vault && !can_act_as_vault?
          raise Exception.new("#{self.class.name} can't act as an identity vault.")
        end
      end
      
      # Override this to perform actions that must be performed the
      # when the connector starts running. (Eg, opening network connections)
      def started; end
      
      # Subclasses must override this to
      # interface with the external system and generate events.
      # These events are yielded to the passed in block to process.
      # This method will be called repeatedly until the connector is
      # stopped.
      def check; end
      
      # Override this to perform actions that must be performed when
      # the connector exits (eg closing network conections).
      def stopped; end


      # Call check repeatedly (or once if in once_only mode)
      # to generate events.
      # Should generally only be called by the pipeline to which it is attached.
      def start
        log.info "#{name}: Starting"
        @running = true
        started()
        while @running
          check do |event|
            unless is_delete_echo?(event) || is_echo?(event)
              call_if_exists :source_transform, event
              yield(event)
            end
          end

          if once_only
            log.debug "#{name}: Once only, setting @running to false"
            @running = false
          else
            log.debug "#{name}: sleeping"
            sleep 1
          end
        end
        stopped
      end

      # Politely stop the connector.
      def stop
        log.info "#{name}: Stopping"
        @running = false
      end

      
      # Convenience method for consistency
      def is_vault?
        @is_vault
      end
      

      def process(event)
        case event.type
        when :add: return perform_add(event)
        when :delete: return perform_delete(event)
        when :modify: return perform_modify(event)
        else
            raise Exception.new("#{name}: Unknown event type '#{event.type}' received")
        end
      end
      
      def perform_add event
        log.info "Adding '#{event.target_path}' to '#{name}'"
        raise Exception.new("#{name}: Entry with path '#{event.target_path}' already exists, add failing.") if self[event.target_path]
        if is_vault? && event.association_key != nil && path_for_association_key(event.association_key)
          raise Exception.new("#{name}: Association_key already in use. Add failing.") 
        end
        call_if_exists(:target_transform, event)
        add event.target_path, event.payload
        return association_key_for(event.target_path) unless is_vault?
        if is_vault? && !event.association_key
          raise Exception.new("#{name}: No association key supplied to add.")
        else
          associate_with_foreign_key(event.association_key, event.target_path)
        end
      end

      def perform_delete event
        raise Exception.new("#{name}: Delete of unassociated object. No action taken.") unless event.association_key
        path = path_for_association_key(event.association_key)
        log.info "Deleting '#{path}' from '#{name}'"
        raise Exception.new("#{name}: Attempted to delete non-existent entry '#{path}'") unless delete(path)
        return nil # don't want to create any new associations
      end
      
      def perform_modify event
        path = path_for_association_key(event.association_key)
        raise Exception.new("#{name}: Attempted to modify non-existent entry '#{path}'") unless self[path]
        call_if_exists(:target_transform, event)
        modify path, event.payload
        return (is_vault?)? nil : association_key_for(event.target_path)
      end


      # Returns the correct id for the given association_key 
      def path_for_association_key(key)
        (is_vault)? path_for_foreign_key(key) : path_for_own_association_key(key)
      end

      # Returns the association key for the given path. Called if this connector is the client.
      # Default implementation returns the path itself. If there is a more
      # effecient key for looking up an entry in the client, override to return
      # that instead.
      def association_key_for(path)
        path
      end
      
      
      # Returns the appropriate entry for the association key. This key will have been provided
      # by a previous call to the association_key method.
      # This will only be called on the client connector. It is not expected that the client will
      # have to store this key.
      def path_for_own_association_key(key)
        key
      end

      # Whether this connector is capable of acting as a vault.
      # The vault is responsible for storing the association key of the client application
      # and must be able to retrieve records for that association key.
      # Typically, databases and directories can act as vaults, text documents and HR or finance
      # applications probably can't.
      # To enable a connector to act as a vault, define the following methods:
      # => entry_for_foreign_key(pipeline_id, key)
      # => foreign_key_for()
      # and entry_for_association_key(key).
      def can_act_as_vault?
        defined? associate_with_foreign_key and
        defined? path_for_foreign_key and defined? foreign_key_for
      end

      
      # Attempts to delete non-existent items may occur due to echoing. Many systems won't be able to record
      # the fact that an entry has been deleted rubysync because after the delete, there is no entry left to
      # record the information in. Therefore, they may issue a notification that the item has been deleted. This
      # becomes an event and the connector won't know that it caused the delete. The story usually has a reasonably happy
      # ending though.
      # The inappropriate delete event is processed by the pipeline and a delete attempt is made on the
      # datastore that actually triggered the original delete event in the first place. Most of the time, there will
      # be no entry there for it to delete and it will fail harmlessly.
      # Problems may arise, however, if the original delete event was the result of manipulation in the pipeline and
      # the original entry is in fact supposed to stay there. For example, say a student in an enrolment system was marked
      # as not enrolled anymore. This modify event is translated by the pipeline that connects to the identity vault to become
      # a delete because only the enrolment system is interested in non-enrolled students. As the student is removed
      # from the identity vault, a new delete event is generated targeted back and the enrolment system.
      # If the pipeline has been configured to honour delete requests from the vault to the enrolment system then the
      # students entry in the enrolment system would be deleted.
      def is_delete_echo? event
        false #TODO implement delete event caching
      end
      
      def is_echo?; false end
      
      # Called by unit tests to inject data
      def test_add id, details
        add id, details
      end
      
      # Called by unit tests to modify data
      def test_modify id, details
        modify id, details
      end
      
      # Called by unit tests to delete a record
      def test_delete id
        delete id
      end
  
      
    end
  end
end
