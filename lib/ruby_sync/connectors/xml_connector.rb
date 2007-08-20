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


lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
$VERBOSE = false
#require 'xmlsimple'
#$VERBOSE = true



module RubySync::Connectors
  class XmlConnector < RubySync::Connectors::BaseConnector

#    attr_accessor :data
    option :filename

    def each_entry
      with_xml(:read_only=>true) do |content|
        content.each do |entry|
          operations = create_operations_for(entry[1][0])
          yield RubySync::Event.add(self, entry[0], nil, operations)
        end
      end
    end
    
    def add id, operations
      with_xml do |content|
        content[id] = perform_operations(operations)
      end
    end
    
    def modify id, operations
      with_xml do |content|
        existing = content[id][0] || {}
        content[id] = perform_operations(operations, existing)
      end
    end
    
    def delete id
      with_xml do |content|
        content.delete(id)
      end
    end
    
    def [](id)
      value = nil
      with_xml(:read_only=>true) do |content|
        value = content[id]
      end
      value
    end

    def []=(id, value)
      with_xml do |content|
        content[id] = value 
      end
    end
    
    
    def self.sample_config
          return <<END
          #
          # filename should be the full name of the file containing
          # the xml representation of the synchronized content
          #
          filename "/tmp/rubysync.xml"
END
    end    

private

    
    def with_xml options={}
      content = (File.exist?(filename))? content = XmlSimple.xml_in(filename) : {}
      yield content
      XmlSimple.xml_out(content, {'OutputFile'=>filename}) unless options[:read_only]
    end

  end
end