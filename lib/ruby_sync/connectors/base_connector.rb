#!/usr/bin/env ruby
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
#  Copyright (c) 2009 Nowhere Man
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



module RubySync::Connectors
  class BaseConnector
      
    include RubySync::Utilities
    meta_eval { include RubySync::Utilities }
    include ConnectorEventProcessing
    include CopyEntryChangeTracking
      
    attr_accessor :once_only, :name, :is_vault, :pipeline, :parse_all_entries, :last_sync_info
    class << self; attr_accessor :parse_all_entries, :last_sync_info; end

    def initialize options={}
      base_path # call this once to get the working directory before anything else
      # in the connector changes the cwd
      options = self.class.default_options.merge(options)
      once_only = false
      self.name = options[:name]
      self.is_vault = options[:is_vault]
      self.parse_all_entries = self.class.parse_all_entries = (self.class.parse_all_entries.nil?) ? true : self.class.parse_all_entries
      if is_vault && !can_act_as_vault?
        raise "#{self.class.name} can't act as an identity vault."
      end
      options.each do |key, value|
        if self.respond_to? "#{key}="
          self.send("#{key}=", value)
        else
          log.debug "#{name}: doesn't respond to #{key}="
        end
      end

    end      
      

    # Subclasses must override this. Called by perform_add to actually
    # store the new record in the datastore. Returned value will be used
    # as the association id if this connector is acting as the client.
    def add id, operations
      raise "add method not implemented"
    end
      
      
    # Override this to return a string that will be included within the class definition of
    # of configurations based on your connector.
    def self.sample_config
    end

    def self.event_method name,&blk
      define_method name do |event|
        event.instance_eval(&blk)
      end
    end

     
    def self.target_transform(&blk) event_method :target_transform,&blk; end
    
    # Subclasses must override this to
    # interface with the external system and generate entries for every
    # entry in the scope passing the entry path (id) and its data (as a hash of arrays).
    # This method will be called repeatedly until the connector is
    # stopped.
    def each_entry
      raise "Not implemented"
    end


    # Call each_change repeatedly (or once if in once_only mode)
    # to generate events.
    # Should generally only be called by the pipeline to which it is attached.
    def start &blk
      log.debug "#{name}: Started"
      @running = true
      sync_started()
      while @running
        each_change do |event|
          if event.type == :force_resync
            each_entry(&blk)
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
      sync_stopped
    end

      
    # Called by start() after last call to each_change or each_entry
    def sync_stopped; end
      
    # Called by start() before first call to each_change or each_entry
    def sync_started; end

    # Override this to perform actions that must be performed the
    # when the connector starts running. (Eg, opening network connections)
    def started
    end
      
    # Override this to perform actions that must be performed when
    # the connector exits (eg closing network conections).
    def stopped; end

      
    # Politely stop the connector.
    def stop
      log.info "#{name}: Attempting to stop"
      @running = false
    end

      
    def is_vault?
      @is_vault
    end

#    def get_parse_all_entries # unused
#      self.class.parse_all_entries
#    end
#
#    def set_parse_all_entries(value) # unused
#      @parse_all_entries = value
#      self.class.parse_all_entries = value
#    end

    def self.set_parse_all_entries(value)
      @parse_all_entries = value
    end

#    def get_last_sync_info # unused
#      log.debug "get last_sync_info #{self.class.last_sync_info}"
#      self.class.last_sync_info
#    end

    def set_last_sync_info(value)
      log.debug "#{name}: set last_sync_info with #{value}"
      @last_sync_info = value
      self.class.last_sync_info = value
    end
    alias :last_sync_info= set_last_sync_info

    # Override this to return the last synchronization info of your connector
    def extract_last_sync_info
       return Time.now if parse_all_entries
       log.warn "You must override this method to return the last synchronization information of your connector"
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
    def can_act_as_vault?
      defined? associate and
        defined? path_for_association and
        defined? association_key_for and
        defined? remove_association and
        defined? associations_for
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

    def clean
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


    # Return an array of possible fields for this connector.
    # Implementations should override this to query the datasource
    # for possible fields.
    def self.fields
      nil
    end

    # Ensures that the named connector is loaded and returns its class object
    #    def self.class_for connector_name
    #      name = class_name_for connector_name
    #      (name)? eval(name) : nil
    #    end

    #    # Return the class name for a path style connector name
    #    def self.class_name_for connector_name
    #      '::' + "#{connector_name}_connector".camelize
    #    end

    def self.sample_config
      return <<-END
          # The comments in this file should help you to create a custom connector.
          # We're going to assume that you know how to program in Ruby. If you don't then
          # quickly pop-off and learn it: http://ruby-lang.org.
          #
          # Edit the comments as you go to describe the specifics of your connector.
          # If you need more information, consult http://rubysync.org/docs/developer/connectors
          
          
          # Call the option class method to declare the options used to configure
          # your connector.
          # eg.
          #
          #option :filename, :frequency
          #
          # Would define an option called filename and one called frequency. You could then follow up with:
          #
          # filename 'default.csv'
          # frequency 10
          #
          # And, of course, the same could be done in child classes (aka configuration files)
          # The value set becomes available as a readable method of the same name in instances
          # of the class.                   
          
          
          ####### Configuration methods
          
          # Return the list of the fields available for this connector. Feel free to print an
          # informative message if you can't determine the available fields for the datastore.
          def self.fields
            puts "The author of #{__FILE__} hasn't got around to implementing the working out the default fields yet :>"
          end
          
          # Return the string that will be inserted as the contents of the subclass created
          # when "rubysync connnector blah -t your_connector" is run.
          def self.sample_config
            return <<-END
              # This is the default configuration provided by #{__FILE__}
              #
              # Kind of sparse. Isn't it?
              #
              #
	  end
    end

    ####### Reading methods
          
    # If your datasource supports random access (as would, for example, a database) then
    # implement the following:
    #
    #def [](path)
    #  #return the entry at location indicated by 'path'
    #  #An 'entry' is a hash where the key is the attribute name and the value is an
    #  #array containing the value or values for the the attribute
    #end               
          
    # Subclasses must override this to
    # interface with the external system and generate entries for every
    # entry in the scope passing the entry path (id) and its data (as a hash of arrays).
    def each_entry
      raise "Not implemented"
    end

    # Subclasses MAY override this to interface with the external system
    # and generate an event for every change that affects items within
    # the scope of this connector.
    #
    # The default behaviour is to compare a hash of each entry in the
    # database with a stored hash of its previous value and generate
    # add, modify and delete events appropriately. This is normally a very
    # inefficient way to operate so overriding this method is highly
    # recommended if you can detect changes in a more efficient manner.
    #
    # This method will be called repeatedly until the connector is
    # stopped.
    #def each_change
    #end
          
    ######## Writing methods
          
    # Apply operations to create database a entry at path
    def add(path, operations)
    end
          
    # Apply operations to alter database entry at path
    def modify(path, operations)
    end

    # Remove database entry at path
    def delete(path)
    end
      END
    end

    def self.track_changes_with method
      include_something_called method, "change_tracking"
    end
		  
    def self.track_associations_with method
      include_something_called method, "association_tracking"
    end

    def self.track_with(tracking_name, options={})
      options = HashWithIndifferentAccess.new(options)
      tracking_class = class_called(tracking_name, "connector")
      unless tracking_class
        log.error "No tracker called #{tracking_name}"
        return
      end
      options[:name] ||= "#{self.name}(track)"
      options[:is_vault] = false
      class_def 'track' do
        @track ||= tracking_class.new(options)
      end      
    end

    private

    # set a default dbm path in case one of the dbm tracking
    # modules is used.
    def dbm_path()
      p = "#{base_path}/db"
      ::FileUtils.mkdir_p p
      ::File.join(p,name)
    end

    def self.include_something_called name, extension, message=nil
      module_name = class_name_for(name, extension)
      m = eval(module_name)
      unless include(m)
        message ||= "Couldn't find a module called #{module_name}"
        log.error message
      end
    end

    def self.options options
      @options = options
    end
        
    def self.default_options
      @options ||= {}
    end
  
  end
end

