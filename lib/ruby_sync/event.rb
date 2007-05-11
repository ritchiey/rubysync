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
  
  class Association
    attr_accessor :context, # many associations will share the same context
                            # it is a function of pipeline and the client connector
                            # to which the association applies
                  :key      # the key is unique within the context and vault
    
    def initialize(context, key)
      @context = context
      @key = key
    end
    
    def to_s
      "#{context}:#{key}"
    end

  end  
  
  class Event

    attr_accessor :type,        # delete, add, modify ...
                  :source,
                  :payload,
                  :source_path,
                  :target_path,
                  :association

    
    def self.delete source, source_path, association=nil
      self.new(:delete, source, source_path, association)
    end
    
    def self.add source, source_path, association=nil, payload=nil
      self.new(:add, source, source_path, association, payload)
    end
    
    def self.modify source, source_path, association=nil, payload=nil
      self.new(:modify, source, source_path, association, payload)
    end

    def initialize type, source, source_path=nil, association=nil, payload=nil
      self.type = type
      self.source = source
      self.source_path = source_path
      self.association = make_association(association)
      self.payload = payload
      @target_path = nil
    end

    def retrieve_association(context)
      if self.source.is_vault?
        self.association ||=  self.source.association_for(context, self.source_path)
      else
        if self.association # association key was supplied when the event was created
          self.association.context = context # just add the context
        else
          key = self.source.own_association_key_for(self.source_path)
          @association = Association.new(context, key)
        end
      end
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
      %w{ @type @source_path @target_path @association @payload}
    end
    
    # True if this event will lead to the field name given being set.
    # If value is non-nil then if it will lead to it being set to
    # the value given.
    # Note: This implementation is not completely accurate. Just looks
    # at the last operation in the payload. A better implementation would
    # look at all items that affect the named field to work out the value.
    def sets_value? subject, value=nil
      return false if @payload == nil
      @payload.reverse_each do |op|
        return true if op.subject == subject && (value == nil || op.values == value.as_array)
      end
      return false
    end
    
    # Remove any operations from the payload that affect fields with the given key or
    # keys (key can be a single field name or an array of field names).
    def drop_changes_to subject
      subjects = subject.as_array
      uncommitted_operations
      @uncommitted_operations = @uncommitted_operations.delete_if {|op| subjects.include? op.subject }
    end

    def drop_all_but_changes_to subject
      subjects = subject.as_array
      @uncommitted_operations = uncommitted_operations.delete_if {|op| !subjects.include?(op.subject)}
    end
    
     # Add a value to a given subject if there are no 
     def add_default field_name, value
       add_value field_name, value unless sets_value? field_name
     end
     
     
     def add_value field_name, value
       uncommitted_operations << Operation.new(:add, field_name, value.as_array)
     end
     
     def set_value field_name, value
       uncommitted_operations << Operation.new(:replace, field_name, value.as_array)
     end

  
    def uncommitted_operations
      @uncommitted_operations ||= @payload || []
      return @uncommitted_operations
    end
 
    def uncommitted_operations= ops
      @uncommitted_operations = ops
    end
  
    # Add one or more operations to the list to be performed.
    # The operations won't be added to the payload until commit_changes
    # is called and won't be added at all if rollback_changes is called
    # first.
    def append new_operations
      uncommitted_operations
      @uncommitted_operations += new_operations.as_array
    end

    # Rollback any changes that 
    def rollback_changes
      @uncommitted_operations = nil
    end
  
    def commit_changes
      if uncommitted_operations 
        @payload = uncommitted_operations
        @uncommitted_operations = nil
      end
    end
  
  protected

  # Try to make a sensible association from the passed in object
  def make_association o
    if o.kind_of? Array
      return Association.new(o[0],o[1])
    elsif o.kind_of? RubySync::Association
      return o
    else
      return Association.new(nil, o)
    end
  end
      


    # Yield to block for each operation in the payload for which the the subject is
    # the specified subject
    def each_operation_on subject
      return unless payload
      subjects = subject.as_array.map {|s| s.to_s}
      payload.each do |op|
        if subjects.include?(op.subject.to_s)
          yield(op)
        end
      end
    end

  end  

  
end

    
    