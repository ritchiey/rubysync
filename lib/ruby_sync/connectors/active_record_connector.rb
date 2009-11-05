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

require 'erb'
$VERBOSE=false
require "active_record"
#$VERBOSE=true
require "ruby_sync/connectors/base_connector"

module RubySync::Connectors

  # You can initialize this connector with the name of a model and the path to a rails application:
  # eg: vault :ActiveRecord, :application=>'path/to/rails/application', :model=>:user
  class ActiveRecordConnector < RubySync::Connectors::BaseConnector

    include ActiveRecordAssociationTracking
    include ActiveRecordChangeTracking
    
    option :ar_class, :model, :changes_model, :associations_model, 
      :application, :rails_env, :columns, :find_method, :find_filter,
      :db_type, :db_host, :db_username, :db_password, :db_name, :db_encoding, :db_pool, :db_config

    rails_env 'development'
    find_method :find
    find_filter :all
    db_type 'postgresql'
    db_username 'rails_user'
    db_password 'your_password'
    db_host 'localhost'
    db_name "rubysync_#{get_rails_env}"
    db_encoding "utf8"
    db_pool 5    
    # Default db_config in case we're not sucking the config out of a rails app
    db_config(
      :adapter=>get_db_type,
      :host=>get_db_host,
      :database=>get_db_name,
      :username=>get_db_username,
      :password=>get_db_password,
      :encoding=>get_db_encoding,
      :pool=>get_db_pool
    )

    def method_missing(name)
      if name == :model and respond_to? :changes_model
        changes_model
      elsif name == :changes_model and respond_to? :model
        model
      else
        super
      end
    end

    def track_class
      if respond_to? :track
        track.ar_class
        #    elsif is_vault? and @pipeline
        #      @pipeline.client.track_class
      end
    end

    def initialize options={}
      super options
     
      # Rails app specified, use it to configure
      if application          
        
        # Load the database configuration
        rails_app_path = File.expand_path(application)
        ::Module.rails_app_path = rails_app_path
        db_config_filename = File.join(rails_app_path, 'config', 'database.yml')
        new_db_config = YAML.load(File.read(db_config_filename)).with_indifferent_access[rails_env]

        #Add rails application relative path for sqlite databases
        if new_db_config['adapter'].match('^(jdbc)?sqlite(2|3)?$')
          new_db_config['database'] = rails_app_path + '/' + new_db_config['database'] if Pathname.new(new_db_config['database']).relative?
        end
        
        # Load db config
        self.class.db_config new_db_config
       
        # Require the models
        @models||=[]
        Dir[File.join(rails_app_path, 'app','models', '*.rb')].each do |filepath|
          require_dependency filepath
          filepath = filepath.gsub("\\","/")#For Windows
          filename = File.basename(filepath,File.extname(filepath))
          class_name = filename.camelize          
          klass = class_name.constantize        
          
          if(klass.respond_to?(:descends_from_active_record?) && klass.descends_from_active_record?)
            @models << class_name
            # Establish connection
            klass.establish_connection db_config# if defined? klass.establish_connection
            # Setup logger for activerecord
            klass.logger = Logger.new(File.open(File.join(rails_app_path, 'log', "#{rails_env}.log"), 'a'))
          end
        end
      end
         
      self.class.ar_class model.to_s.camelize.constantize      
    end

    def self.fields
      c = self.new
      return get_columns if respond_to? :get_columns
      c.ar_class.content_columns.map {|col| col.name }
    end

    def self.sample_config
      return <<END

    # Uncomment and adjust the following if your app is a Ruby on Rails
    # application. It will grab the config from the RoR database.yml.
    # application '/path/to/a/rails/application'
    # model 'name_of_model_to_sync'
    # rails_env 'development'   # typically development or production 

    # OR

    # Uncomment and adjust the following if your app is not
    # a Ruby on Rails application (EXPERIMENTAL)
    #
    # db_type 'mysql'  # eg 'db2', 'mysql', 'oci', 'postgresql', 'sqlite', 'sqlserver'
    # db_host 'localhost' # network name of db server
    # db_name 'database_name' # Name of the database (not the table)
    # model 'my_model'
    # class MyModel < ActiveRecord::Base
    #     set_table_name "users"
    # end
    
END
    end
      
    
    def each_entry
      ar_class.send(:"#{find_method}", *find_args) do |record|
        yield entry_from_active_record(record)
      end
    end     

    def find_args(extras=[])
      args = [find_filter]
      if respond_to?(:columns)
        columns << ar_class.primary_key.to_sym unless columns.include?(ar_class.primary_key.to_sym)
        args << {:select => columns.join(", ")}      
      end
      args + extras
      args.merge_hashes
    end

    # Override default perform_add because ActiveRecord is different in that
    # the target path is ignored when adding a record. ActiveRecord determines
    # the id on creation.
    def perform_add event
      log.info "Adding '#{event.target_path}' to '#{name}'"
      ar_class.new() do |record|
        populate(record, perform_operations(event.payload))
        #log.info(record.inspect)
        record.save!
        update_mirror record.send(:"#{ar_class.primary_key}")
        if is_vault?
          associate event.association, record.send(:"#{ar_class.primary_key}")
        end
        record.send(:"#{ar_class.primary_key}")
      end
    rescue => ex
      log.warn ex
      return nil
    end

      
    def modify(path, operations)
      ar_class.find(path) do |record|
        populate(record, perform_operations(operations))
        record.save
      end
    end
    
    def delete(path)
      if path.is_a?(Hash)
        ar_class.destroy_all path[:conditions] if path.key?(:conditions)
      else
        ar_class.destroy path
      end
    end

    def [](path)
      entry_from_active_record(ar_class.find(path))
    rescue ActiveRecord::RecordNotFound
      return nil
    end

    def self.track_with(connector_name, options={})
      options = HashWithIndifferentAccess.new(options)
      connector_class = class_called(connector_name, "connector")
      unless connector_class
        log.error "No connector called #connector_name}"
        return
      end
      options[:name] ||= "#{self.name}(track)"
      options[:is_vault] = false
      class_def 'track' do
        @track ||= connector_class.new(options)
      end
    end
    
    #    def Object.const_missing(name)
    #      if name == :RAILS_ROOT
    #        File.expand_path(application)
    #      else
    #        super
    #      end
    #    end

    private

    def populate record, content
      ar_class.content_columns.each do |c|
        if !respond_to?(:columns) || self.class.fields.include?(c.name.to_sym)
          record[c.name] = content[c.name][0] if content[c.name]
        end
      end
    end

    def entry_from_active_record record
      entry = {}
      record.class.content_columns.each do |col|
        key = col.name
        if !respond_to?(:columns) || self.class.fields.include?(key.to_sym)
          value = record.send key
          entry[key.to_s] = value if key and value
        end
      end
      entry
    end

    #    def RAILS_ROOT(value)
    #       Object.const_set(:RAILS_ROOT, value) unless Object.const_defined? :RAILS_ROOT
    #    end

  end

end
