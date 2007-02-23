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



module RubySync
  class Event

    attr_accessor :type, :source, :payload, :source_path, :target_path, :association_key

    
    def self.delete source, source_path, association_key
      self.new(:delete, source, source_path, association_key)
    end
    
    def self.add source, source_path, association_key=nil, payload=nil
      self.new(:add, source, source_path, association_key, payload)
    end
    
    def self.modify source, source_path, association_key=nil, payload=nil
      self.new(:modify, source, source_path, association_key, payload)
    end
    
    def initialize type, source, source_path=nil, association_key=nil, payload=nil
      self.type = type
      self.source = source
      self.source_path = source_path
      self.association_key = association_key
      self.payload = payload
      @target_path = nil
    end
    
    def merge other
      # TODO implement merge
      log.warning "Event.merge not yet implemented"
    end
    
    # Retrieves all known values for the record affected by this event and
    # sets the event's type to :add
    # If the source connector doesn't implement retrieve we'll assume thats
    # because it can't and that it gave us all it had to start with.
    def convert_to_add
      log.info "Converting '#{type}' event to add"
      if (source.respond_to? :retrieve)
        full = source.retrieve(source_path)
        payload = full.payload
      end
      @type = :add
    end
          
    
    def to_yaml_properties
      %w{ @type @source_path @target_path @association_key @payload}
    end
    
    # True if this event will lead to the field name given being set
    # if value is non-nil then if it will lead to it being set to
    # the value given.
    # Note: This implementation is not completely accurate. Just looks
    # at the last operation in the payload. A better implementation would
    # look at all items that affect the named field to work out the value.
    def sets_value? field_name, value=nil
      return false if @payload == nil
      @payload.reverse_each do |r|
        return true if r[1] == field_name && (value == nil || r[2] == value.as_array)
      end
      return false
    end
    
    # Remove any operations from the payload that affect fields with the given key or
    # keys (key can be a single field name or an array of field names)
    def drop_changes_to key
      keys = key.as_array
      return unless @payload
      @payload = @payload.delete_if {|command| keys.include? command[1] }
    end
    
    def add_default field_name, value
      add_value field_name, value unless sets_value? field_name
    end
    
    def add_value field_name, value
      payload << [:add, field_name, value.as_array]
    end

    def set_value field_name, value
      payload << [:replace, field_name, value.as_array]
    end
  end  
end

    
    