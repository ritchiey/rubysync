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

$VERBOSE=false
require "active_record"
require "active_record/observer"

gem 'sqlite3-ruby', '<1.3.0' if RUBY_VERSION <= "1.8.6" # Version 1.3.x isn't compatible with Ruby 1.8.6
#$VERBOSE=true
require "ruby_sync/connectors/base_connector"

module RubySync::Connectors

  # You can initialize this connector with the name of a model and the path to a rails application:
  # eg: vault :ActiveRecord, :application => 'path/to/rails/application', :model => :user
  class ActiveRecordConnector < RubySync::Connectors::BaseConnector

    include ActiveRecordAssociationTracking
    include ActiveRecordChangeTracking
    include ActiveRecordEventTracking

    attr_accessor :rails_app_path

    option :ar_class, :model, :changes_model, :associations_model,
      :application, :rails_env, :columns, :path_column, :find_method, :find_filter, :find_block, :delete_event,
      :db_type, :db_host, :db_username, :db_password, :db_name, :db_encoding, :db_pool, :db_config

    rails_env 'development'
    find_method :all
    find_filter nil
    delete_event false
    db_type 'postgresql'
    db_username 'rails_user'
    db_password 'your_password'
    db_host 'localhost'
    db_name "rubysync_#{get_rails_env}"
    db_encoding "utf8"
    db_pool 5

    # Default db_config in case we're not sucking the config out of a rails app
    db_config(
      :adapter => get_db_type,
      :host => get_db_host,
      :database => get_db_name,
      :username => get_db_username,
      :password => get_db_password,
      :encoding=> get_db_encoding,
      :pool => get_db_pool
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
        if track.respond_to?(:ar_class) && track.ar_class.respond_to?(:descends_from_active_record?) && track.ar_class.descends_from_active_record?
          return track.ar_class
        else
          log.warn "No ActiveRecord tracking class"
          return
        end
      else
         log.error "No track method"
         return
      end
    end

    def self.find_chaining(&block)
      if get_find_method == :find_chaining
        find_block block
        self.new.find_chaining(&block)
      end
    end

    def find_chaining
      if Object.const_defined?('RubySyncEvent') and @models.include?('RubySyncEvent')
       target_class = RubySyncEvent
      else
        target_class = ar_class
      end

      target_class.class_eval do
        meta_def :find_chaining do |*args|
          yield(self,args)
        end
      end
    end

    def initialize options={}
      super options

      # Rails app specified, use it to configure
      if application
        # Load the database configuration
        @rails_app_path = File.expand_path(application)
        if defined?(JRUBY_VERSION)
          require "#{@rails_app_path}/config/initializers/jdbc"
          log.debug "Using JRuby, version: #{JRUBY_VERSION}" # debug
        end

        # Load models path of the rails application
        get_load_paths_method = ActiveSupport::Dependencies.respond_to?(:autoload_paths) ? :autoload_path= :  :load_paths
        set_load_paths_method = ActiveSupport::Dependencies.respond_to?(:autoload_paths=) ? :autoload_paths= :  :load_paths=

        rails_models_path = File.join(rails_app_path, 'app', 'models')
        rails_initializers_path = File.join(rails_app_path, 'config', 'initializers')
        load_paths = ActiveSupport::Dependencies.send(get_load_paths_method) + [rails_initializers_path, rails_models_path]
        ActiveSupport::Dependencies.send(set_load_paths_method, load_paths)

        db_config_filename = File.join(@rails_app_path, 'config', 'database.yml')
        new_db_config = YAML.load(ERB.new(File.read(db_config_filename)).result).with_indifferent_access[rails_env]
        #Add rails application relative path for sqlite databases
        if new_db_config['adapter'].match('^(jdbc)?sqlite(2|3)?$')
          new_db_config['database'] = @rails_app_path + '/' + new_db_config['database'] if Pathname.new(new_db_config['database']).relative?
        end

        # Load db config
        self.class.db_config new_db_config

        # Setup logger for ActiveRecord models
        ActiveRecord::Base.logger = Logger.new(File.open(File.join(@rails_app_path, 'log', "#{rails_env}.log"), 'a'))
        ActiveRecord::Base.logger.level = Logger::INFO if rails_env.to_sym == :production

        ActiveRecord::Base.establish_connection db_config if !ActiveRecord::Base.connected?
        # Require Non-ActiveRecord models before all the models
        Dir[File.join(@rails_app_path, 'app','models', '*_observer.rb')].each do |filepath|
          begin
            require_dependency filepath
            filename = File.basename(filepath,File.extname(filepath))
            class_name = filename.camelize
            class_model = "::#{class_name}".constantize
            if class_model.respond_to? :observe
              ActiveRecord::Base.observers << class_model
            end
            log.debug "Require Non-ActiveRecord model: '#{class_name}' in #{name}"
          rescue Exception => ex
            log.error ex.message
          end
        end

        ActiveRecord::Base.instantiate_observers if !ActiveRecord::Base.observers.blank?

        # Require the ActiveRecord models
        @models||=[]
        Dir[File.join(@rails_app_path, 'app','models', '*.rb')].each do |filepath|
          filepath = filepath.gsub("\\","/") # For Windows
          if filepath.match(/.+\_observer\.rb$/)
            # Do nothing because Observers are already loaded
          else
            require_model(filepath)
          end
        end
      end
      self.class.ar_class model.to_s.camelize.constantize
      self.class.path_column ar_class.primary_key unless respond_to?(:path_column)

      if Object.const_defined?('RubySyncEvent') and @models.include?('RubySyncEvent')
        restore_last_sync_state
      end
    end

    def require_model(filepath)
      begin
        require_dependency filepath
      rescue Exception => ex
        log.error ex.message
      end
      filename = File.basename(filepath,File.extname(filepath))
      class_name = filename.camelize

      class_model = "::#{class_name}".constantize
      # Establish connection only if the model has a corresponding table in the database
      if !@models.include?(class_name) && class_model.respond_to?(:table_name) #&& class_name.underscore.pluralize == class_model.table_name
        @models << class_name
        # Establish connection
        if !class_model.connected?
          if filepath.match(/.+[\\\/]ruby\_sync\_.+\.rb$/)
            class_model.establish_connection db_config
          else
            class_model.establish_connection db_config# if class_model.respond_to? :establish_connection
          end
          log.debug "Database connection etablished for '#{class_name}' in #{name}"
        end

      end
    end

    def self.fields
      return get_columns if respond_to? :get_columns
      c = self.new
      c.ar_class.column_names.sort
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
      find_chaining(&find_block) if !ar_class.respond_to?(find_method)

      ar_class.send(:"#{find_method}", *find_args).each do |record|
        yield record.send(:"#{path_column}"), to_entry(record)
      end
    end

    def find_args(extras=[])
      args = find_filter.is_a?(Array) ? find_filter : [find_filter]
      if respond_to?(:columns)
        columns << path_column.to_sym unless columns.include?(path_column.to_sym)
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
        record.save!
        update_mirror record.send(:"#{path_column}")
        if is_vault?
          associate event.association, record.send(:"#{path_column}")
        end
        record.send(:"#{path_column}")
      end
    rescue => ex
      log.warn ex
      return nil
    end


    def modify(path, operations)
      if (record = ar_class.first( :conditions => { path_column => path } ) )
        if !(ar_operations = perform_operations(operations)).blank?
          log.info "Modifying '#{path}' with '#{ar_operations.inspect}'"
          populate(record, ar_operations)
          record.save!
        end
      else
        nil
      end
    end

    def delete(path)
      if path.is_a?(Hash)
        ar_class.destroy_all path[:conditions] if path.key?(:conditions)
      else
        ar_class.destroy_all( path_column => path )
      end
    end

    def [](path)
      record = ar_class.send(:"find_by_#{path_column}", path)
      (record.blank?)? nil : to_entry(record)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
      return nil
    end

    private

    def populate record, content
      content.keys.each do |key|
        if !respond_to?(:columns) || self.class.fields.include?(key.to_sym)
          record.send("#{key}=", content[key][0]) if record.respond_to?("#{key}=")
        end
      end
    end

    def to_entry active_record
      entry = active_record.attributes
      entry.from_keys(*columns) if respond_to?(:columns) && !columns.empty?
      entry
    end

  end

end
