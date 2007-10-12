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
require 'ruby_sync/operation'
require 'ruby_sync/event'


module RubySync
  VERSION = '0.1.0'
  module Connectors
  end
  module Pipelines
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


# Add an option that will be defined by a class method, stored in a class variable
# and accessible as an instance method
def array_option *names
  names.each do |name|
    meta_def name do |*values|
      class_def name do
        values
      end
      meta_def "get_#{name}" do
        values
      end
    end
  end
end


class File
  def self.delete_if_exists(files)
    files.kind_of?(Array) or files = [files]
    files.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end
end


load_paths = [lib_path]
if (base_path)
  load_paths << File.join(base_path, 'connectors')
  load_paths << File.join(base_path, 'pipelines')
  load_paths << File.join(base_path, 'shared', 'pipelines')
  load_paths << File.join(base_path, 'shared', 'connectors')
  load_paths << File.join(base_path, 'shared', 'lib')
end
Dependencies.load_paths = load_paths
