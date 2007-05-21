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

require 'erb'
$VERBOSE=false
require "active_record"
#$VERBOSE=true
require "ruby_sync/connectors/base_connector"


module RubySync::Connectors

  # You can initialize this connector with the name of a model and the path to a rails application:
  # eg: vault :ActiveRecord, :application=>'path/to/rails/application', :model=>:user
  class ActiveRecordConnector < RubySync::Connectors::BaseConnector


    attr_accessor :ar_class, :model, :application, :rails_env, :db_type, :db_host, :db_name
    
    def initialize options={}
      super options
      @rails_env ||= 'development'
      @db_type ||= 'mysql'
      @db_host ||= 'localhost'
      @db_name ||= "rubysync_#{@rails_env}"
      # Default db_config in case we're not sucking the config out of a rails app
      db_config = {
        :adapter=>@db_type,
        :host=>@db_host,
        :database=>@db_name
      }

      # Rails app specified, use it to configure
      if defined? @application
        # Load the database configuration
        rails_app_path = File.expand_path(@application, File.dirname(__FILE__))
        db_config_filename = File.join(rails_app_path, 'config', 'database.yml')
        db_config = YAML::load(ERB.new(IO.read(db_config_filename)).result)[@rails_env]
        # Require the models
        Dir.chdir(File.join(rails_app_path,'app','models')) do
          Dir.glob('*.rb') { |filename| require filename }
        end
      end

      @model ||= :user
      @ar_class ||= eval("::#{@model.to_s.camelize}")

      ActiveRecord::Base.establish_connection(db_config)
    end


      def self.sample_config
          return <<END
          options(
            #:application=>'/path/to/a/rails/application',
            #:model=>'name_of_model_to_sync'
          )
END
      end

    # Passes a modify event to the passed-in block once for each record
    # added or modified since the last synchronization timestamp for this connector.
    # Passes a delete event for each RubySyncAssociation without a matching
    # record. It then deletes the RubySyncAssociation. In other words, the
    # RubySyncAssociation serves as a tombstone for the deleted record.
    def check
      log.info "Checking '#{ar_class.name}'"
      # TODO: Change to only send through recent changes
      ar_class.find(:all).each do |record|
        log.info "Creating modify event for #{record.id}"
        # create an event from the record
        association = (is_vault?)? nil : record.id
        operations = create_operations_for_active_record record
        yield RubySync::Event.modify(self, record.id,  association, operations)
      end
      # TODO: Find orphaned RubySyncAssociations and generate delete events for
      # them then delete them.
    end


    # Override default perform_add because ActiveRecord is different in that the target path is ignored when adding
    # a record. ActiveRecord determines the id on creation.
    def perform_add event
      log.info "Adding '#{event.target_path}' to '#{name}'"
      @ar_class.new() do |record|
        populate(record, perform_operations(event.payload))
        puts(record.inspect)
        record.save!
        if is_vault?
          associate event.association, record.id
        end
        record.id
      end
    rescue
      return nil
    end

      
    def modify(path, operations)
      @ar_class.find(path) do |record|
        populate(record, perform_operations(operations))
        record.save
      end
    end
    
    def delete(path)
      @ar_class.destroy path
    end
  
    # Implement vault functionality

    def associate association, path
      log.debug "Associating '#{association}' with '#{path}'"
      ::RubySyncAssociation.create :synchronizable_id=>path, :synchronizable_type=>@ar_class.name,
                                   :context=>association.context, :key=>association.key
    end

    def find_associated association
      ::RubySyncAssociation.find_by_context_and_key association.context, association.key
    end

    def path_for_association association
      assoc = ::RubySyncAssociation.find_by_context_and_key association.context, association.key
      (assoc)? assoc.synchronizable_id : nil
    end

    def association_key_for context, path
      record = ::RubySyncAssociation.find_by_synchronizable_id_and_synchronizable_type_and_context path, @model.to_s, context
      record and record.key
    end
    
    def associations_for(path)
      records = ::RubySyncAssociation.find_by_synchronizable_id_and_synchronizable_type(path, @model.to_s)
    end
    
    def remove_association association
       ::RubySyncAssociation.find_by_context_and_key(association.context, association.key).destroy
    rescue ActiveRecord::RecordNotFound
       return nil
    end


    def [](path)
      @ar_class.find(path)
    rescue ActiveRecord::RecordNotFound
      return nil
    end

private

    def populate record, content
      @ar_class.content_columns.each do |c|
        record[c.name] = content[c.name.to_sym][0] if content[c.name.to_sym]
      end
    end

    def create_operations_for_active_record record
      operations = record.class.content_columns.map do |col|
        key = col.name
        value = record.send key
        RubySync::Operation.new(:add, key, value) if key and value
      end
      operations.compact
    end
  end
end
