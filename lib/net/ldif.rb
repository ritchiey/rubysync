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
    

  
  # Represents a mod-spec structure from RFC2849
  class LDIFModSpec # :nodoc:
    attr_accessor :type, :attribute, :values
    def initialize(type, attribute)
      self.type = type
      self.attribute = attribute
      self.values = nil
    end

    def add_change name, value
      if @values
        if @values.kind_of? Array
          @values << value
        else
          @values = [@values, value]
        end
      else
        @values = value
      end
    end

    def changes() [@type.to_sym, @attribute, @values] end
  end

  # Represents an LDIF change record as defined in RFC2849.
  # The RFC specifies that an LDIF file can contain either
  # attrval records (which are just content) or change records
  # which represent changes to the content.
  # This parser puts both types into the change record structure
  # Ldif attrval records simply become change records of type
  # 'add'.
  class ChangeRecord
    attr_accessor :dn, :changetype, :data
    
    def initialize(dn, changetype='add')
      self.dn = dn
      self.changetype = changetype
      @mod_spec = nil
      @data = nil
    end
    
    def to_s
      "#{@dn}\n#{@changetype}\n" +
      @data.inspect
    end
      
    
    def add_value(name, value) # :nodoc:
      # Changetype specified before any other fields
      if name == 'changetype' and !@data
        @changetype = value
        return
      end

      if name == '-' and @changetype != 'modify'
          raise ParsingError.new("'-' is only valid in LDIF change records when changetype is modify")
      end
      
      # Just an ordinary name value pair
      case changetype
      when 'add': add_content(name, value)
      when 'delete':  
        raise ParsingError.new("Didn't expect content when changetype was 'delete', (#{name}:#{value})")
      when 'modify': add_modification(name, value)
      when 'modrdn': add_moddn_value(name,value)
      when 'moddn': add_moddn_value(name, value)
      else
        raise ParsingError.new("Unknown changetype: '#{changetype}'")
      end
    end

    
    def add_modification(name, value)
      @data ||= []
      if name == '-'
        @mod_spec or
          raise ParsingError.new("'-' in LDIF modify record before any actual changes")
        @data << @mod_spec.changes
        @mod_spec = nil
        return
      end
      
      if @mod_spec
        @mod_spec.add_change name,value
      elsif %w{add delete replace}.include? name
        @mod_spec = LDIFModSpec.new(name, value)
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

  end # of class ChangeRecord


  class URLForValue < String # :nodoc:
    def to_s
      filename = self.sub(/^file:\/\//oi, '')
      File.read(filename)
    end
  end

  class Base64EncodedString < String # :nodoc:
    def to_s() Base64.decode64 self; end
  end

  class LDIF

    #FILL = '\s*'
    ATTRIBUTE_DESCRIPTION = '[a-zA-Z0-9.;-]+'
    SAFE_INIT_CHAR = '[\x01-\x09\x0b-\x0c\x0e-\x1f\x21-\x39\x3b\x3d-\x7f]'
    SAFE_CHAR = '[\x01-\x09\x0b-\x0c\x0e-\x7f]'
    SAFE_STRING = "#{SAFE_INIT_CHAR}#{SAFE_CHAR}*"
    BASE64_STRING = '[\x2b\x2f\x30-\x39\x3d\x41-\x5a\x61-\x7a]*'


    # Yields Net::ChangeRecord for each LDIF record in the file.
    # If the file contains attr-val (content) records, they are
    # yielded as Net::ChangeRecords of type 'add'.
    def self.parse(stream)
      return parse_to_array(stream) unless block_given?
      type = nil
      record_number = 0
      record = nil
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
          record = ChangeRecord.new(value)
          next
        end
        
        record or raise ParsingException.new("Expecting a dn, got #{name}: #{value}")        
        record.add_value name, value
      end # of tokens
      yield(record) if record
    end

    def self.parse_to_array(stream)
      changes = []
      parse(stream) do |change|
        changes << change
      end
      changes
    end

    # Yields a series of pairs of the form name, value found in the
    # given stream. Comments (lines starting with #) are removed,
    # base64 values are decoded and folded lines are unfolded.
    # Blank lines are yielded with a nil name, nil value pair.
    # Lines containing only a hyphen are yielded as a name="-",
    # value="-" pair.
    # Values specified as file:// urls as described in RFC2849 are
    # replaced with the contents of the specified file. 
    def self.tokenize(stream)

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
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION})::\s*(#{BASE64_STRING})/oi
          yield(name, value.to_s) if name
          name  = $1
          value = Base64EncodedString.new($2)
          comment = false
          foldable = false # It is but we've got a separate rule for it
          next
        end
        
        # URL value
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION}):<\s*(#{SAFE_STRING})/oi
            yield(name, value.to_s) if name
            name  = $1
            value = URLForValue.new($2)
            comment = false
            foldable = true
            next
          end
        
        # Name:Value pair
        if line =~ /^(#{ATTRIBUTE_DESCRIPTION}):\s*(#{SAFE_STRING})/oi
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
      end # of file
      yield(name, value.to_s) if name
      line_number
    end
    
    private
    
    
    def process(record, type) # :nodoc:
      
    end
    
  end
end