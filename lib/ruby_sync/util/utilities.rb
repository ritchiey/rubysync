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



# Generally useful methods
module RubySync
  module Utilities
    

    # Perform an action and rescue any exceptions thrown, display the exception with the specified text
    def with_rescue text
      begin
        yield
      rescue Exception => exception
        log.warn "#{text}: #{exception.message}"
        log.debug exception.backtrace[0..10].join("\n")
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
    def ensure_dir_exists path
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
      @base_path = find_base_path unless defined? @base_path
      @base_path
    end

    # Locate a configuration directory by checking the current directory and
    # all of it's ancestors until it finds one that looks like a rubysync configuration
    # directory.
    # Returns false if no suitable directory was found
    def find_base_path
      base_path = File.expand_path(".")
      last = nil
      # Keep going up until we start repeating ourselves
      while File.directory?(base_path) && base_path != last && base_path != "/"
        return base_path if File.directory?("#{base_path}/pipelines") &&
                            File.directory?("#{base_path}/connectors")
        last = base_path
        base_path = File.expand_path("#{base_path}/..")
      end
      return false
    end
        
  end
end