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
      event = self.new(:delete, source, source_path)
      event.association_key = association_key
      event
    end
    
    def self.add source, source_path, association_key=nil, payload=nil
      event = self.new(:add, source, source_path, payload)
      event.association_key = association_key
      event
    end
    
    def initialize type, source, source_path=nil, payload=nil
      self.type = type
      self.source = source
      self.source_path = source_path
      self.payload = payload
    end
    
    def merge other
      # TODO implement merge
      log.warning "Event.merge not yet implemented"
    end
    
    # Retrieves all known values for the record affected by this event and
    # sets the event's type to :add
    def convert_to_add
      log.info "Converting '#{type}' event to add"
      full = source.retrieve(source_path)
      payload = full.payload
      type = :add
    end
    
    def to_yaml_properties
      %w{ @type @source_path @target_path @association_key }
    end
    
    
  end
end

    
    