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

lib_path = File.dirname(__FILE__)
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'rubygems'
require 'active_support'
require 'ruby_sync/util/utilities'
require 'ruby_sync/connectors/base_connector'
require 'ruby_sync/pipelines/base_pipeline'
require 'ruby_sync/operation'
require 'ruby_sync/event'


# Make the log method globally available
class Object
  def log
    unless defined? @@log
      @@log = Logger.new(STDOUT)
      @@log.level = Logger::DEBUG
      @@log.datetime_format = "%H:%M:%S"
    end
    @@log
  end
end