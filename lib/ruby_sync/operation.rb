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
  
  # Operations that may be performed on an attribute
  class Operation
  
  include RubySync::Utilities
  
  attr_accessor :type, :subject, :values
  
  
    def self.add subject, values
      self.new(:add, subject, values)
    end
    
    def self.delete subject, values=nil
      self.new(:delete, subject, values)
    end
    
    def self.replace subject, values
      self.new(:replace, subject, values)
    end
      
  
    def initialize type, subject, values
      self.type = type.to_sym
      self.subject = subject.to_s
      self.values = values
    end
  
    def ==(o)
      subject == o.subject &&
      type == o.type &&
      values == o.values
    end
    
    remove_method :type=
    def type=(type)
      unless [:add, :delete, :replace].include? type.to_sym
        raise Exception.new("Invalid operation type '#{type}'")
      end
      @type = type
    end
    
    remove_method :values=
    def values=(values)
      @values = (values == nil)? nil : as_array(values)
    end
    
    def value
      @values and @values[0]
    end
    
    def value= new_value
      @values = new_value.as_array
    end

    # Returns a duplicate of this operation but with the subject
    # changed to the specified subject 
    def same_but_on subject
      op = self.dup
      op.subject = subject
      op
    end
    
    # Returns a duplicate of this operation but with the type
    # changed to the specified type
    def same_but_as type
      op = self.dup
      op.type = type
      op.values = nil if type == :delete
      op
    end
    
    # Returns a duplicate of this operation but with the values
    # changed to those specified
    def same_but_with values
      op = self.dub
      op.values = values
      op
    end
    
    def sets_blank?
      [:add, :replace].include? @type and
      (!@values || as_array(@values).select {|v| v && v != ''}.empty?)
    end
    
  end
end
