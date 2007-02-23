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

class Object
  
  # If not already an array, slip into one
  def as_array
    (instance_of? Array)? self : [self]
  end
end

module RubySync
  module Connectors
    class MemoryConnector < RubySync::Connectors::BaseConnector

      def check
        while event = @events.shift
          yield event
        end
      end
  
      def is_echo? event
        event.sets_value?(:modifier, 'rubysync')
      end

      def associate_with_foreign_key(key, path)
        log.info "Associating foreign key '#{key}' with '#{path}'"
        entry = @data[path]
        if entry
          @association_index[key] = path
          entry[:foreign_key] = key
        end
      end

      def path_for_foreign_key(key)
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
  
      # Normally, the add method is called by the pipeline and simply stores
      # the data to the datastore and that's it.
      # In this case, though, we also generate an add event.
      # This simulates the likely effect that an add would have on a proper datastore
      # where doing an add would very likely cause an event to be generated that the
      # pipeline should rightly ignore because it's just a side-effect.
      # In other words, we're simply simulating an undesirable behaviour for testing
      # purposes. 
      def add id, operations
        raise Exception.new("Item already exists") if @data[id]
        @data[id] = perform_operations operations
        association_key = (is_vault?)? nil : association_key_for(id)
        log.info "#{name}: Injecting add event"
        @events << RubySync::Event.add(self, id, association_key, operations.dup)
        return id
      end
      
      def modify id, operations
        raise Exception.new("Attempting to modify non-existent record '#{id}'") unless @data[id]
        perform_operations operations, @data[id]
        association_key = (is_vault?)? nil : association_key_for(id)
        log.info "#{name}: Injecting modify event"
        @events << RubySync::Event.add(self, id, association_key, operations.dup)
        return id
      end
  

      def delete id
        raise Exception.new("Can't delete non-existent item '#{id}'") unless @data[id]
        association_key = (is_vault?)? foreign_key_for(id) : association_key_for(id)
        @association_index.delete association_key
        log.info "#{name}: Injecting delete event"
        @events << (event = RubySync::Event.delete(self, id, association_key))
        @data.delete id
      end

      # Put a clue there that we did this change so that we can detect and filter
      # out the echo.
      def target_transform event
        event.payload << [:add, :modifier, ['rubysync']]
      end
      
      def source_transform event
        event.drop_changes_to [:modifier, :foreign_key]
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

