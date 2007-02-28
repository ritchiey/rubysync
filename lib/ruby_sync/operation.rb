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
  class Operation < Array
  
    def initialise type, subject, values
      self.type = type
      self.subject = subject
      self.values = values
    end
  
    def type; self[0]; end
    def type=(value)
      unless [:add, :delete, :replace].include? value.to_sym
        raise Exception.new("Invalid operation type '#{value}'")
      end
    end
    
    def subject; self[1]; end
    def subject=(subject)
      self[1]= subject
    end
    
    def values
      self[2]
    end
    
    def values=(values)
      self[2] = values.as_array
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