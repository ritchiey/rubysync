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

lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift lib_path unless $:.include?(lib_path)

require 'fileutils'
require 'rubygems'
require 'active_support'
require 'irb'



module Kernel    
  # Make the log method globally available
  def log
    unless defined? @@log
      @@log = Logger.new(STDOUT)
      #@@log.level = Logger::DEBUG
      @@log.datetime_format = "%H:%M:%S"
    end
    @@log
  end    
end

class Array
  def to_ruby
    map {|f| "'#{f}'"}.join(', ')    
  end
end

class String
  # PHP's two argument version of strtr
  def strtr(replace_pairs)
    keys = replace_pairs.map {|a, b| a }
    values = replace_pairs.map {|a, b| b }
    self.gsub(
      /(#{keys.map{|a| Regexp.quote(a) }.join( ')|(' )})/
      ) { |match| values[keys.index(match)] }
  end

  #Convert specials chars to be compliant with Ldap
  def sanitize_ldap
    #self.strtr("*"=>"\\2a","\\"=>"\5c","NUL"=>"\\00","("=> "\\28",")"=>"\\29")
    self.strtr("$"=>"_24","("=> "_28",")"=>"_29")
  end
end

# Generally useful methods
module RubySync
  module Utilities
    @@base_path=nil

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

    def dump_before
      []
    end

    def dump_after() []; end
    def perform_transform name, event, hint=""
      log.info event.to_yaml if dump_before.include?(name.to_sym)
      log.info "performing #{name}"
      call_if_exists name, event, hint
      event.commit_changes
      log.info event.to_yaml if dump_after.include?(name.to_sym)
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
      begin
	something_called name, "pipeline"
      rescue
	log.error "Pipeline named '#{name}' not found."
	nil
      end
    end
    
    
    def connector_called name, message=nil
      begin
	something_called name, "connector"
      rescue
	message ||= "Connector named '#{name}' not found."
        log.error message
	nil
      end
    end

    # Locates and returns an instance of a class for
    # the given name.
    def something_called name, extension, message=nil
      klass = class_called(name, extension, message) and klass.new()
    end

    def class_called name, extension, message=nil
      class_for_name(class_name_for(name, extension), message)
    end
      
    def class_for_name(name, message=nil)
      eval(name)
    rescue
      message ||= "Unable to find class called '#{name}'"
      log.error message
      nil
    end

    def class_name_for name, extension
      "#{name.to_s}_#{extension}".camelize
    end
    
    # Ensure that path is in the search path
    # prepends it if it's not
    def include_in_search_path path
      path = File.expand_path(path)
      $:.unshift path unless $:.include?(path)
    end
    
    # Return the base_path
    ::Kernel.send :define_method, :base_path do
      @@base_path = find_base_path unless @@base_path
      @@base_path
    end

    # Locate a configuration directory by checking the current directory and
    # all of it's ancestors until it finds one that looks like a rubysync configuration
    # directory.
    # Returns false if no suitable directory was found
    ::Kernel.send :define_method, :find_base_path do
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
    def perform_operations operations, record={}, options={}
      subjects = options[:subjects]
      operations.each do |op|
        unless op.instance_of? RubySync::Operation
          log.warn "!!!!!!!!!!  PROBLEM, DUMP FOLLOWS: !!!!!!!!!!!!!!"
          p op
        end
	key = op.subject
        next if subjects and !subjects.include?(key)
        case op.type
        when :add
          if record[key]
            existing = as_array(record[key])
            next if existing == op.values # already same so ignore
            (existing & op.values).empty? or
	      raise "Attempt to add duplicate elements to #{name}"
            record[key] =  existing + op.values
          else
            record[key] = op.values
          end
        when :replace
          record[key] = op.values
        when :delete
          if record[key]
            unless op.value
              record.delete(op.subject)
            else
              record[key] -= op.values
            end
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
          unless op.value
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
