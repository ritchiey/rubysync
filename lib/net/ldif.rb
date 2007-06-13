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

require 'base64'

module Net

  class ParsingError < StandardError; end
    

  class ChangeRecord
    attr_accessor :dn, :changetype, :data
    
    def [](index)
      return nil unless @data
      @data[index]
    end
    
    def initialize(dn, changetype)
      self.dn = dn
      self.changetype = changetype
    end
    
    def add_value(name, value)
      case changetype
      when 'add'
        add_content(name, value)
      when 'delete'
        raise ParsingError.new("Didn't expect content when changetype was 'delete', (#{name}:#{value})")
      when 'modify'
        add_modification(name, value)
      when 'modrdn'
        add_moddn_value(name,value)
      when 'moddn'
        add_moddn_value(name, value)
      else
        raise ParsingError.new("Unknown changetype: '#{changetype}'")
      end
        
    end
    
    def add_modification(name, value)
      if name == '-'
        
        @mod_spec = nil
      end
      @data ||= []
      case @mod_spec
      when 'add':
        @data << [:add, name, value]
      end
    end
    
    def add_moddn_value(name, value)
      #TODO: implement
      #raise Exception.new("Sorry, not yet implemented")
    end


    def add_content(key, value)
      @data ||= {}
      if @data[key]
        if @data[key].kind_of? Array
          @data[key] << value
        else
          @data[key] = [@data[key], value]
        end
      else
        @data[key] = value
      end
    end

    
  end

  class URLForValue < String # :nodoc:
    def to_s
      filename = self.sub(/^file:\/\//oi, '')
      File.read(filename)
    end
  end

  class Base64EncodedString < String # :nodoc:
    def to_s
      Base64.decode64 self
    end
  end

  class LDIF

    #FILL = '\s*'
    ATTRIBUTE_DESCRIPTION = '[a-zA-Z;]'
    SAFE_INIT_CHAR = '[\x01-\x09\x0b-\x0c\x0e-\x1f\x21-\x39\x3b\x3d-\x7f]'
    SAFE_CHAR = '[\x01-\x09\x0b-\x0c\x0e-\x7f]'
    SAFE_STRING = "#{SAFE_INIT_CHAR}#{SAFE_CHAR}*"
    BASE64_STRING = '[\x2b\x2f\x30-\x39\x3d\x41-\x5a\x61-\x7a]*'


    # If stream contains content records, yields Net::ChangeRecord objects.
    # if stream contains change records, yields Net::AttrValueRecord objects. 
    def parse(stream)
      type = nil
      record_number = 0
      record = nil
      dn = nil
      mod_spec = nil
      tokenize(stream) do |name, value|

        # version-spec
        if (name == 'version' and record_number == 0)
          value == '1' or raise ParsingError.new("Don't know how to parse LDIF version '#{value}'")
          next
        end
        
        # Blank line
        # Unless I'm reading the spec wrong, blank lines don't seem to mean much
        # Yet in all the examples, the records seem to be separated by blank lines.
        # TODO: Check whether blank lines mean anything
        next if (name == nil)

        name.downcase!        
        # DN - start a new record
        if name == 'dn'
          # Process existing record
          yield(record) if record
          record = nil # don't know what type it will be yet
          dn = value
          next
        end
        
        # Changetype
        if !record and dn and name == 'changetype'
          record = ChangeRecord.new(dn, value)
          next
        end
        
        if name == '-'
          record.instance_of?(ChangeRecord) or
            raise ParsingError.new("'-' is only valid in LDIF change records")
          record.changetype == 'modify' or
            raise ParsingError.new("'-' is only valid in LDIF change records when changetype is modify")
          mod_spec or
            raise ParsingError.new("'-' in LDIF modify record before any actual changes")
          record.add mod_spec
          mod_spec = nil
          next
        end
        
        
        # Ordinary Name value pair
        if dn and !record
          record = AttrValRecord.new(dn)
        end
        record.add_value(name, value)        

      end
      yield(record) if record
    end


    # Yields a series of pairs of the form name, value found in the
    # given stream. Comments (lines starting with #) are removed,
    # base64 values are decoded and folded lines are unfolded.
    # Blank lines are yielded with a nil name, nil value pair.
    # Lines containing only a hyphen are yielded as a name="-",
    # value="-" pair.
    # Values specified as file:// urls as described in RFC2849 are
    # replaced with the contents of the specified file. 
    def tokenize(stream)

      foldable = false
      comment = false
      name = nil
      value = ""
      line_number = 0
      stream.each_line do |line|
        line_number += 1
        
        # Blank line
        if line.strip.length == 0
          yield(name, value.to_s) if name;name = nil;value = ""
          yield nil,nil
          foldable = false
          comment = false
          next
        end
        
        # Line extension
        if foldable and line[0,1] == ' '
          value << line.chop[1..-1] unless comment
          next
        end
                    
        # Comment
        if line[0,1] == '#'
          yield(name, value.to_s) if name;name = nil;value = ""
          comment = true
          foldable = true
          next
        end

        # Base64 Encoded name:value pair
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION}+)::\s*(#{BASE64_STRING})/oi
          yield(name, value.to_s) if name
          name  = $1
          value = Base64EncodedString.new($2)
          comment = false
          foldable = false # It is but we've got a separate rule for it
          next
        end
        
        # URL value
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION}+):<\s*(#{SAFE_STRING})/oi
            name  = $1
            value = URLForValue.new($2)
            comment = false
            foldable = true
            next
          end
        
        # Name:Value pair
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION}+):\s*(#{SAFE_STRING})/oi
          yield(name, value.to_s) if name
          name = $1; value = $2
          foldable = true
          comment = false
          next
        end
        
        # Hyphen
        if line =~ /^-/o
          yield(name, value.to_s) if name;name = nil;value = ""
          yield('-','-')
          foldable = false
          comment = false
          next
        end

        # Continuation of Base64 Encoded value?
        if value.kind_of?(Base64EncodedString) and line =~ /^ (#{BASE64_STRING})/oi
          value << $1
          next
        end

        raise ParsingError.new("Unexpected LDIF at line: #{line_number}")
      end
      yield(name, value.to_s) if name
      line_number
    end
    
    private
    
    
    def process(record, type) # :nodoc:
      
    end
    
  end
end