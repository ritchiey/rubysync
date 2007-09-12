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
require 'rexml/document'

class REXML::Document
  
  def entry_element_for id
    #    root.each_element_with_attribute('id', id) do |element|
    root.each_element("entry[@id='#{id}']") do |element|
      return element
    end
    nil
  end
  
end

module RubySync::Connectors
  class XmlConnector < RubySync::Connectors::BaseConnector
    
    include REXML

    option :filename

    def each_entry
      with_xml(:read_only=>true) do |xml|
        xml.root.each_element("entry") do |element|
          yield element.attribute('id').value, to_entry(element)
        end
      end
    end
    
    
    def add id, operations
      entry = nil
      with_xml do |xml|
        xml.entry_element_for(id) and raise "Element '#{id}' already exists."
        entry = perform_operations(operations)
      end
      self[id] = entry
      id
    end
    
    def modify id, operations
      entry = nil
      with_xml do |xml|
        existing_entry = to_entry(xml.entry_element_for(id))
        entry = perform_operations(operations, existing_entry)
      end
      self[id] = entry
      id
    end
    
    def delete id
      xpath = "//entry[@id='#{id}']"
      with_xml do |xml|
        xml.root.delete_element xpath
      end
    end
    
    def [](id)
      with_xml(:read_only=>true) do |xml|
        element = xml.entry_element_for(id)
        return (element)? to_entry(element) : nil
      end
    end
    
      

    def []=(id, value)
      with_xml do |xml|
        new_child = to_xml(id, value)
        if old_child = xml.entry_element_for(id)   
          xml.root.replace_child(old_child, new_child)
        else
          xml.root << new_child
        end
      end
    end


    def to_xml key, entry
      el = Element.new("entry")
      el.add_attribute('id', key)
      entry.each do |key, values|
        el << attr = Element.new("attr")
        attr.add_attribute 'name', key
        values.as_array.each do |value|
          value_el = Element.new('value')
          attr << value_el.add_text(value)
        end
      end
      el
    end



    
    def to_entry entry_element
      entry = {}
      if entry_element
        entry_element.each_element("attr") do |child|
          entry[child.attribute('name').value] = values = []
          child.each_element("value") do |value_element|
            values << value_element.text
          end
        end
      end
      entry
    end
      
    
    def self.sample_config
      return %q(
#
# "filename" should be the full name of the file containing
# the xml representation of the synchronized content.
# You probably want to change this:
#
filename "/tmp/rubysync.xml"
      )
    end    


    # Should be re-entrant within a single thread but isn't
    # thread-safe.
    def with_xml options={}
      unless @with_xml_invoked
        begin
          @with_xml_invoked = true
          File.exist?(filename) or File.open(filename,'w') {|file| file.write('<entries/>')}
          File.open(filename, "r") do |file|
            file.flock(File::LOCK_EX)
            @xml = Document.new(file)
            begin
              yield @xml
            ensure
              File.open(filename, "w") do |out|
                @xml.write out
              end
            end
          end
        ensure
          @with_xml_invoked = false
        end
      else # this is a nested call so we don't need to read or write the file
        yield @xml
      end
    end
  end
end