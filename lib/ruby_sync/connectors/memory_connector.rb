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


require "yaml"

module RubySync
  module Connectors
    class MemoryConnector < RubySync::Connectors::BaseConnector

      def check
        while event = @events.shift
          yield event
        end
      end
  
      def is_echo? event
        event.payload && event.payload[:modifier] == 'rubysync'
      end
  
      def associate_with_foreign_key(key, path)
        log.info "Associating foreign key '#{key}' with '#{path}'"
        entry = @data[path]
         if entry
           @association_index[key] = entry
           entry[:foreign_key] = key
         end
      end

      def entry_for_foreign_key(key)
        @association_index[key]
      end
  
      def foreign_key_for(path)
        log.debug "Retrieving foreign key for '#{path}'"
        entry = @data[path]
        if entry && foreign_key = entry[:foreign_key]
          log.debug "Found foreign key '#{foreign_key}'"
          return foreign_key
        else
          log.debug "No foreign key found."
        end
        return nil
      end
  

      def initialize options
        super
        @data = {}
        @events = []
        @association_index = {}
      end
  
      def add id, details
        raise Exception.new("Item already exists") if @data[id]
        @data[id] = details
        association_key = (is_vault?)? nil : association_key_for(id)
        @events << RubySync::Event.add(self, id, association_key, details)
        return id
      end
  
      def delete id
        raise Exception.new("Can't delete non-existent item '#{id}'") unless @data[id]
        association_key = (is_vault?)? foreign_key_for(id) : association_key_for(id)
          @association_index.delete association_key
          @events << (event = RubySync::Event.delete(self, id, association_key))
        @data.delete id
      end
  
      def drop_pending_events
        @events = []
      end
    
      def [](key)
        @data[key]
      end
  
      def []=(key, value)
        @data[key] = value
      end
  
    end
  end
end

