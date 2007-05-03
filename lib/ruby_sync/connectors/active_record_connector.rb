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

require 'ERB'
$VERBOSE=false
require "active_record"
$VERBOSE=true
require "ruby_sync/connectors/base_connector"


# class Person < ActiveRecord::Base
#   has_many :association_keys, :class_name => "AssociationKey", :foreign_key => "record_id"
#   has_many :interests
#   has_many :hobbies, :class_name => "ClassName", :foreign_key => "hobbies_id"
# end
# 
# class AssociationKey < ActiveRecord::Base
#   belongs_to :person, :class_name => "Person", :foreign_key => "record_id"
# end
# 
# class Interest < ActiveRecord::Base
#   belongs_to :person
#   belongs_to :hobby
# end
# 
# class Hobby < ActiveRecord::Base
#   has_many :interests
#   has_many :people, :through=>:interests
# end

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
      if @application
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


    # Override default perform_add because ActiveRecord is different in that the target path is ignored when adding
    # a record. ActiveRecord determines the id on creation.
    def perform_add event
      log.info "Adding '#{event.target_path}' to '#{name}'"
      @ar_class.new() do |record|
        poplulate(record, perform_operations(event.payload))
        puts(record.inspect)
        record.save!
        if is_vault?
          associate_with_foreign_key event.association_key, record.id
        end
        record.id
      end
    end

      
    def modify(path, operations)
      @ar_class.find(path) do |record|
        poplulate(record, perform_operations(operations))
        record.save
      end
    end
    
    def delete(path)
      @ar_class.delete path
    end
  
    # Implement vault functionality

    # TODO: These method signatures need to change to include a connector or pipeline id so that
    # we can distinguish between foreign keys for the same record but different
    # connectors/pipelines.

    def associate_with_foreign_key pipeline, key, path
      ::AssociationKey.create({:record_id=>path, :pipeline=>pipeline, :value=>key})
    end

    def path_for_foreign_key pipeline, key
      assoc = AssociationKey.find :first, :conditions=>["pipeline=? and value=?", pipeline, key]
      (assoc)? assoc.synchronizable_id : nil
    end

    def foreign_key_for pipeline, path
      record = AssociationKey.find :first, :conditions=>["pipeline=? and synchable_id=?", pipeline, path]
      record.value
    end
    
    
    def remove_foreign_key pipeline, key
       ::AssociationKey.find_by_pipeline_and_value(pipeline, key).destroy
     rescue ActiveRecord::RecordNotFound
       return nil
    end


    def [](path)
      @ar_class.find(path)
    rescue ActiveRecord::RecordNotFound
      return nil
    end

private

    def poplulate record, content
      @ar_class.content_columns.each do |c|
        record[c.name] = content[c.name.to_sym][0] if content[c.name.to_sym]
      end
    end

  end
end
