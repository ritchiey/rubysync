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

    def check
      while event = @events.shift
        yield event
      end
    end

    def is_echo? event
      event.sets_value?(:modifier, 'rubysync')
    end

    def associate(association, path)
      path = normalize(path)
      log.info "Associating '#{association}' with '#{path}'"
      entry = @data[path]
      if entry
        (@association_index[association.context] ||= {})[association.key] = path
        (entry[:association] ||= {})[association.context] = association.key
      end
    end

    def path_for_association(association)
      context = @association_index[association.context] || {}
      context[association.key.to_s]
    end

    def association_key_for(context, path)
      path = normalize(path)
      log.debug "Retrieving association key for '#{path}' within '#{context}'"
      entry = @data[path]
      unless entry
        p @data
      end
      if entry && entry[:association] && key = entry[:association][context]
        return key
      end
      log.info "No association found."
      log.debug entry.inspect
      return nil
    end
    
    def associations_for path
      path = normalize path
      entry = @data[path]
      (entry[:association] || {}).map do |context, key|
        RubySync::Association.new(context, key)
      end
    end
    
    def remove_association(association)
      path = path_for_association association
      context = @association_index[association.context]
      context.delete(association.key) if context
      entry = @data[path]
      if entry
        entry_context = (entry[:association] || {})[association.context]
        entry_context.delete(association.key) if entry_context
      end
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
      id = normalize id
      raise Exception.new("Item already exists") if @data[id]
      log.debug "Adding new record with key '#{id}'"
      @data[id] = perform_operations operations
      association_key = (is_vault?)? nil : [nil, own_association_key_for(id)]
      log.info "#{name}: Injecting add event"
      @events << RubySync::Event.add(self, id, association_key, operations.dup)
      return id
    end

    def modify id, operations
      id = normalize id
      raise Exception.new("Attempting to modify non-existent record '#{id}'") unless @data[id]
      perform_operations operations, @data[id]
      association_key = (is_vault?)? nil : [nil, own_association_key_for(id)]
      log.info "#{name}: Injecting modify event"
      if is_vault?
        associations_for(id).each do |association|
          @events << (event = RubySync::Event.modify(self, id, association))
        end
      else
        association = [nil, own_association_key_for(id)]
        @events << (event = RubySync::Event.modify(self, id, association))
      end

      @events << RubySync::Event.modify(self, id, association_key, operations.dup)
      return id
    end


    def delete id
      id = normalize id
      unless @data[id]
         log.warn "Can't delete non-existent item '#{id}'"
         return
       end
      log.info "#{name}: Injecting delete events"
      if is_vault?
        associations_for(id).each do |association|
          @events << (event = RubySync::Event.delete(self, id, association))
          @association_index.delete association
        end
      else
        association = [nil, own_association_key_for(id)]
        @events << (event = RubySync::Event.delete(self, id, association))
      end
      @data.delete id
    end

    # Put a clue there that we did this change so that we can detect and filter
    # out the echo.
    def target_transform event
      event.payload << RubySync::Operation.new(:add, :modifier, ['rubysync'])
    end
    
    def source_transform event
      event.drop_changes_to [:modifier, :foreign_key]
    end

    def drop_pending_events
      @events = []
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

