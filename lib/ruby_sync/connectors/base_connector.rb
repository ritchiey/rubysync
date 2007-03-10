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

require 'ruby_sync/connectors/connector_event_processing'

module RubySync
  module Connectors
    
    class BaseConnector
      
      include RubySync::Utilities
      include ConnectorEventProcessing
      
      attr_accessor :once_only, :name, :is_vault
      
      
      def initialize options={}
        once_only = false
        self.name = options[:name]
        self.is_vault = options[:is_vault]
        if is_vault && !can_act_as_vault?
          raise Exception.new("#{self.class.name} can't act as an identity vault.")
        end
        options.each do |key, value|
          if self.respond_to? "#{key}="
            self.send("#{key}=", value) 
          else
            log.debug "#{name}: doesn't respond to #{key}="
          end
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
        log.info "#{name}: Started"
        @running = true
        started()
        while @running
          check do |event|
            if is_delete_echo?(event) || is_echo?(event)
              log.debug "Ignoring echoed event"
            else
              call_if_exists :source_transform, event
              yield(event)
            end
          end

          if once_only
            log.debug "#{name}: Stopped"
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
        log.info "#{name}: Attempting to stop"
        @running = false
      end

      
      # Convenience method for consistency
      def is_vault?
        @is_vault
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
      # => path_for_foreign_key(pipeline_id, key)
      # => foreign_key_for(path)
      # and associate_with_foreign_key(key, path).
      def can_act_as_vault?
        defined? associate_with_foreign_key and
        defined? path_for_foreign_key and
        defined? foreign_key_for and
        defined? remove_foreign_key
      end

      # def associate_with_foreign_key key, path
      # end
      # 
      # def path_for_foreign_key key
      # end
      # 
      # def foreign_key_for path
      # end
      #
      # def remove_foreign_key key
      # end

      # Should only be called on the vault. Returns the entry associated with
      # the foreign key passed. Some connectors may wish to override this if
      # they have a more efficient way of retrieving the record from the foreign
      # key.
      def find_associated foreign_key
        path = path_for_foreign_key foreign_key
        self[path]
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
      
      def is_echo? event; false end
      
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
  
      # Return an array of operations that would create the given record
      # if applied to an empty hash.
      def create_operations_for record
        record.keys.map {|key| Operation.new(:add, key, record[key])}
      end


      # Performs the given operations on the given record. The record is a
      # Hash in which each key is a field name and each value is an array of
      # values for that field.
      # Operations is an Array of RubySync::Operation objects to be performed on the record.
      def perform_operations operations, record={}
        operations.each do |op|
          unless op.instance_of? Operation
            log.warn "!!!!!!!!!!  PROBLEM, DUMP FOLLOWS: !!!!!!!!!!!!!!"
            p op
          end
          case op.type
          when :add
            if record[op.subject]
              existing = record[op.subject].as_array
              unless (existing & op.values).empty?
                raise Exception.new("Attempt to add duplicate elements to #{name}")
              end
              record[op.subject] =  existing + op.values
            else
              record[op.subject] = op.values
            end
          when :replace
            record[op.subject] = op.values
          when :delete
            if value == nil || value == "" || value == []
              record.delete(op.subject)
            else
              record[op.subject] -= values
            end
          else
            raise Exception.new("Unknown operation '#{op.type}'")
          end
        end
        return record
      end

    end
  end
end

