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

lib_path = File.dirname(__FILE__)
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'rubygems'
require 'active_support'
require 'ruby_sync/util/utilities'
require 'ruby_sync/util/metaid'
#require 'ruby_sync/connectors/base_connector'
#require 'ruby_sync/pipelines/base_pipeline'
require 'ruby_sync/operation'
require 'ruby_sync/event'

class Object

  # If not already an array, slip into one
  def as_array
    (instance_of? Array)? self : [self]
  end

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

class Module
  # Add an option that will be defined by a class method, stored in a class variable
  # and accessible as an instance method
  def option *names
    names.each do |name|
      meta_def name do |value|
        class_def name do
          value
        end
        meta_def "get_#{name}" do
          value
        end
      end
    end
  end
end

class Configuration

  include RubySync::Utilities

  def initialize
    include_in_search_path "#{base_path}/pipelines"
    include_in_search_path "#{base_path}/connectors"
    include_in_search_path "#{base_path}/shared/connectors"
    include_in_search_path "#{base_path}/shared/pipelines"    
    include_in_search_path "#{base_path}/shared/lib"

    lib_path = File.dirname(__FILE__)
    require_all_in_dir "#{lib_path}/ruby_sync/connectors", "*_connector.rb"
    require_all_in_dir "#{base_path}/shared/connectors", "*_connector.rb"
    require_all_in_dir "#{lib_path}/ruby_sync/pipelines", "*_pipeline.rb"
    require_all_in_dir "#{base_path}/shared/pipelines", "*_pipeline.rb"
  end

  # We find the first directory in the search path that is a parent of the specified
  # directory and do our requires relative to that in order to increase the likelihood
  # that duplicate requires will be recognised.
  def require_all_in_dir(dir, glob="*.rb")
    expanded = File.expand_path dir
    return unless File.directory? expanded
    
    base = $:.detect do |path_dir|
      expanded_pd = File.expand_path(path_dir)
      expanded[0, expanded_pd.length] == expanded_pd
    end
    
    prefix = (base && File.expand_path(base) != expanded)? expanded[File.expand_path(base).length+1, expanded.length]+"/" : ""

    # puts $:.join "\n"
    # puts "expanded = '#{expanded}'"
    # puts "base = '#{base}'"
    # puts "prefix = '#{prefix}'"

    Dir.chdir dir do |cwd|
      Dir.glob(glob) do |filename|
        require prefix + filename
      end
    end
  end

end

Configuration.new


  
