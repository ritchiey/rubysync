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


require "yaml"


module RubySync::Connectors
  class MemoryConnector < RubySync::Connectors::BaseConnector


    def each_entry
      @data.each do |key, entry|
        yield key, entry
      end
    end


    def initialize options
      super
      @data = {}
    end

    def add id, operations
      id = normalize id
      raise Exception.new("Item already exists") if @data[id]
      log.debug "Adding new record with key '#{id}'"
      @data[id] = perform_operations operations
      association_key = (is_vault?)? nil : [nil, own_association_key_for(id)]
      return id
    end

    def modify id, operations
      id = normalize id
      raise Exception.new("Attempting to modify non-existent record '#{id}'") unless @data[id]
      perform_operations operations, @data[id]
      return id
    end


    def delete id
      id = normalize id
      unless @data[id]
         log.warn "Can't delete non-existent item '#{id}'"
         return
       end
      @data.delete id
    end

    
  
    def [](key)
      @data[normalize(key)]
    end
      
    def []=(key, value)
      @data[normalize(key)] = value
    end

private

    def normalize(identifier)
      identifier.to_s
    end

  end
end

