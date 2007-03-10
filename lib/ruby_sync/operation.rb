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
  
  # Operations that may be performed on an attribute
  class Operation
  
  attr_accessor :type, :subject, :values
  
  
    def self.add subject, values
      self.new(:add, subject, values)
    end
    
    def self.delete subject, values
      self.new(:delete, subject, values)
    end
    
    def self.replace subject, values
      self.new(:replace, subject, values)
    end
      
  
    def initialize type, subject, values
      self.type = type
      self.subject = subject
      self.values = values
    end
  
    remove_method :type=
    def type=(type)
      unless [:add, :delete, :replace].include? type.to_sym
        raise Exception.new("Invalid operation type '#{value}'")
      end
      @type = type
    end
    
    remove_method :values=
    def values=(values)
      @values = values.as_array
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
      op
    end
    
    # Returns a duplicate of this operation but with the values
    # changed to those specified
    def same_but_with values
      op = self.dub
      op.values = values
      op
    end
    
    
  end
end