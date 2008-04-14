#!/usr/bin/env ruby
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
#
# This file is part of RubySync.
#
# RubySync is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# RubySync is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with RubySync; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) ||
  $:.include?(File.expand_path(lib_path))

require 'ruby_sync'

module RubySync
  module Connectors
    class CompareConnector < RubySync::BaseConnector

      option :target, :report
      

      def initialize options={}
	super options
      end
   

      def started
	target.started
	report.started
      end

      def each_entry(&blk)
	target.each_entry(&blk)
      end

      def self.fields
	target.class.fields
      end



      def self.sample_config
	return <<END
     #The compare connector is for internal use only. 
     #You probably don't want to do what you seem to be doing.
END
      end



      def add(path, operations)
	report.add(path, operations)
      end

      def modify(path, operations)
	report.modify(path, operations)
      end

      def delete(path)
	report.delete(path)
      end

      def [](path)
	target[path]
      end

      # Called by unit tests to inject data
      def test_add id, details
      end

      def target_transform event
	target.target_transform(event)
      end

    end

  end
end
