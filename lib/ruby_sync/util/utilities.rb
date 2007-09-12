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


require 'fileutils'
require 'irb'


class ::File
  def self.delete_if_exists(files)
    files.kind_of?(Array) or files = [files]
    files.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end
end

# Generally useful methods
module RubySync
  module Utilities
    
    @@base_path=nil

    # Make the log method globally available
    def log
      unless defined? @@log
        @@log = Logger.new(STDOUT)
        #@@log.level = Logger::DEBUG
        @@log.datetime_format = "%H:%M:%S"
      end
      @@log
    end    
    
    # If not already an array, slip into one
    def as_array o
      (o.instance_of? Array)? o : [o]
    end
    
    # Perform an action and rescue any exceptions thrown, display the exception with the specified text
    def with_rescue text
      begin
        yield
      rescue Exception => exception
        log.warn "#{text}: #{exception.message}"
        log.debug exception.backtrace.join("\n")
      end
    end    
    
    def call_if_exists(method, event, hint="")
      result = nil
      if respond_to? method
        with_rescue("#{method} #{hint}") {result = send method, event}
      else
        log.debug "No #{method}(event) method, continuing #{hint}"
      end
      return result
    end

    def log_progress last_action, event, hint=""
      log.info "Result of #{last_action}: #{hint}\n" + YAML.dump(event)
    end
    
    
    # Ensure that a given path exists as a directory
    def ensure_dir_exists paths
      as_array(paths).each do |path|
        raise Exception.new("Can't create nil directory") unless path
        if File.exist? path
          unless File.directory? path
            raise Exception.new("'#{path}' exists but is not a directory")
          end
        else
          log.info "Creating directory '#{path}'"
          FileUtils.mkpath path
        end
      end
    end
    
    def pipeline_called name
      something_called name, "pipeline"
    end
    
    
    def connector_called name
      something_called name, "connector"
    end

    # Locates and returns an instance of a class for
    # the given name.
    def something_called name, extension
      filename = "#{name.to_s}_#{extension}"
      $".include?(filename) or require filename or return nil
      eval(filename.camelize).new
    end
    
    # Ensure that path is in the search path
    # prepends it if it's not
    def include_in_search_path path
      path = File.expand_path(path)
      $:.unshift path unless $:.include?(path)
    end
    
    # Return the base_path 
    def base_path
      @@base_path = find_base_path unless @@base_path
      @@base_path
    end

    # Locate a configuration directory by checking the current directory and
    # all of it's ancestors until it finds one that looks like a rubysync configuration
    # directory.
    # Returns false if no suitable directory was found
    def find_base_path
      bp = File.expand_path(".")
      last = nil
      # Keep going up until we start repeating ourselves
      while File.directory?(bp) && bp != last && bp != "/"
        return bp if File.directory?("#{bp}/pipelines") &&
        File.directory?("#{bp}/connectors")
        last = bp
        bp = File.expand_path("#{bp}/..")
      end
      return false
    end
       
    # Make and instance method _name_ that returns the value set by the
    # class method _name_.
    # def self.class_option name
    #   self.class_eval "def #{name}() self.class.instance_variable_get :#{name}; end"
    #   self.instance_eval "def #{name}(value) @#{name}=value; end"
    # end
    
    def get_preference(name, file_name=nil)
      class_name ||= get_preference_file
    end
    
    def set_preference(name)
      
    end
    
    def get_preference_file_path name
      dir = "#{ENV[HOME]}/.rubysync"
      Dir.mkdir(dir)
      "#{dir}#{file}"
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
            existing = as_array(record[op.subject])
            next if existing == op.values # already same so ignore
            (existing & op.values).empty? or
            raise "Attempt to add duplicate elements to #{name}"
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

      
    # Filter operations to eliminate those that would have
    # no effect on the record. Returns the resulting array
    # of operations.
    def effective_operations operations, record={}
      effective = []
      operations.each do |op|
        existing = as_array(record[op.subject] || [])
        case op.type
        when :add
          if existing.empty?
            effective << op
          else
            next if existing == op.values # already same so ignore
            effective << Operation.replace(op.subject, op.values)
          end
        when :replace
          if existing.empty?
            effective << Operation.add(op.subject, op.values)
          else
            next if existing == op.values
            effective << op
          end
        when :delete
          if [nil, "", []].include?(op.values)
            effective << op if record[op.subject]
          else
            targets = op.values & existing
            targets.empty? or effective << Operation.delete(op.subject, targets)
          end
        else
          raise Exception.new("Unknown operation '#{op.type}'")
        end
      end
      effective
    end
 
  end
end