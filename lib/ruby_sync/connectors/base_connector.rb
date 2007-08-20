#!/usr/bin/env ruby
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
require 'dbm'
require 'digest/md5'

module RubySync::Connectors
    class BaseConnector
      
      include RubySync::Utilities
      include ConnectorEventProcessing
      
      attr_accessor :once_only, :name, :is_vault
      option  :dbm_path
      
      # set a default dbm path
      def dbm_path() "#{base_path}/db/#{name}"; end

      # Stores association keys indexed by path:association_context
      def path_to_association_dbm_filename
        dbm_path + "_path_to_assoc"
      end
      
      # Stores paths indexed by association_context:association_key
      def association_to_path_dbm_filename
        dbm_path + "_assoc_to_path"
      end
      
      # Stores a hash for each entry so we can tell when
      # entries are added, deleted or modified
      def mirror_dbm_filename
        dbm_path + "_mirror"
      end
      
      def initialize options={}
        base_path # call this once to get the working directory before anything else
                  # in the connector changes the cwd
        options = self.class.default_options.merge(options)
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
      
      
      # Override this to return a string that will be included within the class definition of
      # of configurations based on your connector.
      def self.sample_config
      end
      
      # Override this to perform actions that must be performed the
      # when the connector starts running. (Eg, opening network connections)
      def started
      end
      
      # Subclasses must override this to
      # interface with the external system and generate entries for every
      # entry in the scope passing the entry path (id) and its data (as a hash of arrays).
      # This method will be called repeatedly until the connector is
      # stopped.
      def each_entry
        raise "Not implemented"
      end

      # Subclasses must override this to interface with the external system
      # and generate an event for every change that affects items within
      # the scope of this connector.
      # todo: Make the default behaviour to build a database of the key of
      # each entry with a hash of the contents of the entry. Then to compare
      # that against each entry to see if it has changed.
      def each_change
        DBM.open(self.mirror_dbm_filename) do |dbm|
          # scan existing entries to see if any new or modified
          each_entry do |path, entry|
            digest = digest(entry)
            #puts "each_change calculating digest for:\n#{entry.inspect}"
            unless stored_digest = dbm[path.to_s] and digest == stored_digest
              operations = create_operations_for(entry)
              yield RubySync::Event.add(self, path, nil, operations) 
              dbm[path.to_s] = digest
            end
          end
          
          # scan dbm to find deleted
          dbm.each do |key, stored_hash|
            unless self[key]
              yield RubySync::Event.delete(self, key)
              dbm.delete key
            end
          end
        end        
      end
      
      def digest(o)
        Digest::MD5.hexdigest(Marshal.dump(o))
      end
      
      # Override this to perform actions that must be performed when
      # the connector exits (eg closing network conections).
      def stopped; end


      # Call each_change repeatedly (or once if in once_only mode)
      # to generate events.
      # Should generally only be called by the pipeline to which it is attached.
      def start &blk
        log.info "#{name}: Started"
        @running = true
        started()
        while @running
          each_change do |event|
            if event.type == :force_resync
              each_entry &blk
              next
            end
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

      
      def is_vault?
        @is_vault
      end
      
      # Returns the correct id for the given association 
      def path_for_association(association)
        (is_vault?)?
          path_for_foreign_key(association) : path_for_own_association_key(association.key)
      end


      # Returns the association key for the given path. Called if this connector is
      # the client.
      # The default implementation returns the path itself. If there is a more
      # efficient key for looking up an entry in the client, override to return
      # that instead.
      def own_association_key_for(path)
        path
      end
      
      
      # Returns the appropriate entry for the association key. This key will have been provided
      # by a previous call to the association_key method.
      # This will only be called on the client connector. It is not expected that the client will
      # have to store this key.
      def path_for_own_association_key(key)
        key
      end
      
      # Returns the entry matching the association key. This is only called on the client.
      def entry_for_own_association_key(key)
        self[path_for_own_association_key(key)]
      end
      
      # True if there is an entry matching the association key. Only called on the client.
      # Override if you have a quicker way of determining whether an entry exists for
      # given key than retrieving the entry.
      def has_entry_for_key?(key)
        entry_for_own_association_key(key)
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
        defined? associate and
        defined? path_for_association and
        defined? association_key_for and
        defined? remove_association and
        defined? associations_for
      end


      # Store association for the given path
      def associate association, path
        DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs_string = dbm[path.to_s]
          assocs = (assocs_string)? Marshal.load(assocs_string) : {}
          assocs[association.context] = association.key
          dbm[path.to_s] = Marshal.dump(assocs)
        end
        DBM.open(association_to_path_dbm_filename) do |dbm|
          dbm[association.to_s] = path
        end
      end
      
      def path_for_association association
        DBM.open(association_to_path_dbm_filename) do |dbm|
          dbm[association.to_s]
        end
      end
      
      # Default implementation does nothing
      def associations_for path
        DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs_string = dbm[path.to_s]
          assocs = (assocs_string)? Marshal.load(assocs_string) : {}
          assocs.values
        end
      end

      # Default implementation does nothing
      def remove_association association
        path = nil
        DBM.open(association_to_path_dbm_filename) do |dbm|
          return unless path =dbm.delete(association.to_s)
        end
        DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs_string = dbm[path]
          assocs = (assocs_string)? Marshal.load(assocs_string) : {}
          assocs.delete(association.context) and dbm[path.to_s] = Marshal.dump(assocs)
        end
      end

      # Could be more efficient for the default case where the
      # associations are actually stored as a serialized hash but
      # then it wouldn't be as generic and other implementations would
      # have to reimplement it.
      # def association_key_for context, path
      #   raise "#{name} is not a vault." unless is_vault?
      #   associations_for(path).each do |assoc|
      #     (c, key) = assoc.split(RubySync::Association.delimiter, 2)
      #     return key if c == context 
      #   end
      #   return nil
      # end

      def association_key_for context, path
        DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs_string = dbm[path.to_s]
          assocs = (assocs_string)? Marshal.load(assocs_string) : {}
          assocs[context.to_s]
        end
      end

      
      # Return the association object given the association context and path.
      # This should only be called on the vault.
      def association_for(context, path)
        raise "#{name} is not a vault." unless is_vault?
        key = association_key_for context, path
        key and RubySync::Association.new(context, key)
      end

      # Should only be called on the vault. Returns the entry associated with
      # the association passed. Some connectors may wish to override this if
      # they have a more efficient way of retrieving the record for a given
      # association.
      def find_associated association
        path = path_for_association association
        path and self[path]
      end
      
      # The context to be used to for all associations created where this
      # connector is the client.
      def association_context
        self.name
      end
      
      def remove_mirror
        File.delete(mirror_dbm_filename) if File.exist?(mirror_dbm_filename) 
      end
      
      def remove_associations
        File.delete(association_to_path_dbm_filename) if File.exist?(association_to_path_dbm_filename)
        File.delete(path_to_association_dbm_filename) if File.exist?(path_to_association_dbm_filename)
      end

      def clean
        remove_associations
        remove_mirror
      end
      
      # Attempts to delete non-existent items may occur due to echoing. Many systems won't be able to record
      # the fact that an entry has been deleted by rubysync because after the delete, there is no entry left to
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
        record.keys.map {|key| RubySync::Operation.new(:add, key, record[key])}
      end


      # Performs the given operations on the given record. The record is a
      # Hash in which each key is a field name and each value is an array of
      # values for that field.
      # Operations is an Array of RubySync::Operation objects to be performed on the record.
      def perform_operations operations, record={}
        operations.each do |op|
          unless op.instance_of? RubySync::Operation
            log.warn "!!!!!!!!!!  PROBLEM, DUMP FOLLOWS: !!!!!!!!!!!!!!"
            p op
          end
          case op.type
          when :add
            if record[op.subject]
              existing = record[op.subject].as_array
              (existing & op.values).empty? or
                raise Exception.new("Attempt to add duplicate elements to #{name}")
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


      # Return an array of possible fields for this connector.
      # Implementations should override this to query the datasource
      # for possible fields.
      def self.fields
        nil
      end

      # Ensures that the named connector is loaded and returns its class object
      def self.class_for connector_name
        name = class_name_for connector_name
        (name)? eval("::"+name) : nil
      end

      # Ensures that the named connector is loaded and returns its class name.
      def self.class_name_for connector_name
        filename = "#{connector_name}_connector"
        class_name = filename.camelize
        eval "defined? #{class_name}" or
        $".include?(filename) or
        require filename or
        raise Exception.new("Can't find connector '#{filename}'")
        class_name
      end

private

      def self.options options
        @options = options
      end
        
      def self.default_options
        @options ||= {}
      end
  
    end
end

