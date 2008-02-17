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



module RubySync
  
   class Association
    attr_accessor :context, # many associations will share the same context
                            # it is a function of pipeline and the client connector
                            # to which the association applies
                  :key      # the key is unique within the context and vault
    
    
    def self.delimiter; '$'; end
    
    def initialize(context, key)
      @context = context
      @key = key
    end
    
    def to_s
      "#{context}#{self.class.delimiter}#{key}"
    end

  end  
  
  
  # Represents a change of some type to a record in the source datastore.
  # If the event type is :add or :modify then the payload will be an
  # array of RubySync::Operations describing changes to the attributes of the
  # record.
  class Event
    
    include RubySync::Utilities

    attr_accessor :type,        # :delete, :add, :modify, :disassociate
                  :source,
                  :target,
                  :payload,
                  :source_path,
                  :target_path,
                  :association

    def self.force_resync source
      self.new(:force_resync, source)
    end
    
    def self.delete source, source_path, association=nil
      self.new(:delete, source, source_path, association)
    end
    
    def self.add source, source_path, association=nil, payload=nil
      self.new(:add, source, source_path, association, payload)
    end
    
    def self.modify source, source_path, association=nil, payload=nil
      self.new(:modify, source, source_path, association, payload)
    end

    # Remove the association between the entry on the source and
    # the associated entry (if any) on the target.
    def self.disassociate source, source_path, association=nil, payload=nil
      self.new(:disassociate, source, source_path, association, payload)
    end

    def initialize type, source, source_path=nil, association=nil, payload=nil
      self.type = type.to_sym
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
    
    def associated?
      self.association && self.association.context && self.association.key
    end
    
    # Reduces the operations in this event to those that will
    # alter the target record
    def merge other
      @payload = effective_operations(@payload, other)
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

    
    def convert_to_modify(other)
      log.info "Converting '#{type}' event to modify"

      # The add event contained an operation for each attribute of the source record.
      # Therefore, we should delete any attributes in the target record that don't appear
      # in the event.
      affected = affected_subjects
      other.each do |key, value|
        unless affected.include? key
          log.info "Adding delete operation for #{key}"
          @payload << Operation.delete(key)
        end
      end 

      @type = :modify
    end
          
    # Return a list of subjects that this event affects
    def affected_subjects
      @payload.map {|op| op.subject}.uniq
    end

    def hint
      "(#{source.name} => #{target.name}) #{source_path}"
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
        return true if op.subject == subject.to_s && (value == nil || op.values == as_array(value))
      end
      return false
    end
    
    # Remove any operations from the payload that affect fields with the given key or
    # keys (key can be a single field name or an array of field names).
    def drop_changes_to *subjects
      subjects = subjects.flatten.collect {|s| s.to_s}
      uncommitted_operations
      @uncommitted_operations = @uncommitted_operations.delete_if {|op| subjects.include? op.subject }
    end

    def drop_all_but_changes_to *subjects
      subjects = subjects.flatten.collect {|s| s.to_s}
      @uncommitted_operations = uncommitted_operations.delete_if {|op| !subjects.include?(op.subject.to_s)}
    end
   
   def delete_when_blank
       @uncommitted_operations = uncommitted_operations.map do |op| 
         if op.sets_blank?
	   @type == :modify ? op.same_but_as(:delete) : nil
	 else
	   op
	 end
       end.compact
   end    
       
     
     # Add a value to a given subject unless it already sets a value
     def add_default field_name, value
       add_value(field_name.to_s, value) unless sets_value? field_name.to_s
     end
     
     
     def add_value field_name, value
       uncommitted_operations << Operation.new(:add, field_name.to_s, as_array(value))
     end
     
     def set_value field_name, value
       uncommitted_operations << Operation.new(:replace, field_name.to_s, as_array(value))
     end

    def values_for field_name, default=[]
      values = perform_operations @payload, {}, :subjects=>[field_name.to_s]
      values[field_name.to_s] || default
    end
    alias_method :values_of, :values_for 
    
    def value_for field_name, default=''
      values = values_for field_name
      values[0] || default
    end
    alias_method :value_of, :value_for 
           
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
      @uncommitted_operations += as_array(new_operations)
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
    
    # Typically this will be called in the 'transform_in' and 'transform_out'
    # blocks in a pipeline configuration.
    def map(left, right=nil, &blk)
      if right
        drop_changes_to left
        @uncommitted_operations = uncommitted_operations.map do |op|
          (op.subject.to_s == right.to_s)? op.same_but_on(left.to_s) : op
        end
      elsif blk and [:add, :modify].include? @type
        drop_changes_to left.to_s
        uncommitted_operations << RubySync::Operation.replace(left.to_s, blk.call) 
      end
    end
    
    def place(&blk)
      self.target_path = blk.call
    end
  
  protected

  # Try to make a sensible association from the passed in object
  def make_association o  
    if o.kind_of?(Array) and o.size == 2
      return Association.new(o[0],o[1])
    elsif o.kind_of? RubySync::Association
      return o
    elsif o
      return Association.new(nil, o)
    else
      nil
    end
  end
      


    # Yield to block for each operation in the payload for which the subject is
    # the specified subject
    def each_operation_on subject
      return unless payload
      subjects = as_array(subject).map {|s| s.to_s}
      payload.each do |op|
        if subjects.include?(op.subject.to_s)
          yield(op)
        end
      end
    end

  end  

  
end

    
    
