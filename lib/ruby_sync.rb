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

# Enabled Ruby Enterprise Edition's copy-on-write friendly garbage collector
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end

lib_path = File.dirname(__FILE__)
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'rubygems'
require 'active_support'
require 'ruby_sync/util/utilities'
require 'ruby_sync/util/metaid'
require 'ruby_sync/operation'
require 'ruby_sync/event'

$KCODE = 'UTF8'

Time.zone = 'UTC' # You can override this timezone

module RubySync
  VERSION = '0.2.1'
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
      if !self.respond_to?(name)
        meta_def name do |*values|
          if values.is_a?(Enumerable) && values.length > 1
            value = values
          elsif values
            value = values.first
          end

          instance_variable_set("@meta_#{name}", value)

          class_def name do
            ( class_eval("instance_variable_get('@meta_#{name}')") )? class_eval("instance_variable_get('@meta_#{name}')") : value
          end

          class_def "set_#{name}" do |v|
            class_eval("instance_variable_set('@meta_#{name}', '#{v}')")
          end
          class_eval("alias :#{name}= :set_#{name}")

          meta_def "get_#{name}" do
            instance_variable_get("@meta_#{name}") || (respond_to?(:superclass) && superclass && superclass.instance_variable_get("@meta_#{name}"))
          end
        end
      end
    end
  end

  # TODO merge this method with #option method
  def track_option *names
    names.each do |name|
      if !self.respond_to?("set_#{name}")
        meta_def "set_#{name}" do |*values|
          value = if values.is_a?(Enumerable) && values.length > 1
            values
          elsif values
            values.first
          end

          instance_variable_set("@meta_#{name}", value)
          class_def "get_#{name}" do
            (class_eval("instance_variable_get('@meta_#{name}')")) ? class_eval("instance_variable_get('@meta_#{name}')") : value
          end
          class_eval("alias :#{name} :get_#{name}")

          class_def "set_#{name}" do |v|
            class_eval("instance_variable_set('@meta_#{name}', '#{v}')")
          end
          class_eval("alias :#{name}= :set_#{name}")
        end
        instance_eval("alias :#{name}= :set_#{name}")
      end
      if !self.respond_to?("get_#{name}")
        meta_def "get_#{name}" do
          instance_variable_get("@meta_#{name}")
        end
        instance_eval("alias :#{name} :get_#{name}")
      end
    end
  end

  #  alias :track_option :option

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

ActiveSupport::Dependencies.load_paths = load_paths


