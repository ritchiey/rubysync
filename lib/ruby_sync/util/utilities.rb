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

lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift lib_path unless $:.include?(lib_path)

require 'fileutils'
require 'rubygems'
require 'active_support'
require 'irb'
require 'net/ldap'



module Kernel    
  # Make the log method globally available
  def log
    unless defined? @@log
      @@log = Logger.new(STDOUT)
      #@@log.level = Logger::DEBUG
      @@log.datetime_format = "%H:%M:%S"
    end
    @@log
  end

  alias_method(:method_missing_without_dependency, :method_missing)
  def method_missing(method_id, *args)
    loaded = false
    unless Module.rails_app_path.nil?
      begin
        loaded = true
        require_dependency "#{Module.rails_app_path}/app/models/#{method_id.to_s}"
      rescue MissingSourceFile
        loaded = false
      end
    end

    if loaded
      method_id
    else      
      method_missing_without_dependency method_id, *args
    end
  end
end

module Net
  class LDAP
    
    # Update the value of an attribute.
    # #update_attribute can be thought of as equivalent to calling #add_attribute
    # followed by #delete_value. It takes the full DN of the entry to modify,
    # the name (Symbol or String) of the attribute, and the value (String or
    # Array). If the attribute does not exist, it will be created with the
    # caller-specified value(s). If the attribute does exist, its values will be
    # _discarded_ and replaced with the caller-specified values.
    #
    # Returns True or False to indicate whether the operation
    # succeeded or failed, with extended information available by calling
    # #get_operation_result. See also #add_attribute and #delete_value.
    #
    #  dn = "cn=modifyme,dc=example,dc=com"
    #  ldap.update_attribute dn, :mail, "oldmailaddress@example.com", "newmailaddress@example.com"
    #
    def update_attribute dn, attribute, old_value, new_value

      unless result=(add_attribute(dn, attribute, new_value) and delete_value(dn, attribute, old_value))
         log.error "Result: #{get_operation_result.code}"
         log.error "Message: #{get_operation_result.message}"
         raise Exception.new("Unable to update attribute: #{attribute}")
      end

      result
    end

    # Delete a value of an attribute.
    # Takes the full DN of the entry to modify, and the
    # name (Symbol or String) of the value to delete.
    #
    # Returns True or False to indicate whether the operation
    # succeeded or failed, with extended information available by calling
    # #get_operation_result. See also #add_attribute and #update_attribute.
    #
    #  dn = "cn=modifyme,dc=example,dc=com"
    #  ldap.delete_value dn, :mail, "oldmailaddress@example.com"
    #
    def delete_value dn, attribute, value
        unless result = (modify :dn => dn, :operations => [[:delete, attribute, value]])
         log.error "Result: #{get_operation_result.code}"
         log.error "Message: #{get_operation_result.message}"
         raise Exception.new("Unable to delete value: #{value} of attribute: #{attribute}")
      end
      
      result
    end
  end
end

module Enumerable
  def pluck(method, *args)
    map { |x| x.send method, *args }
  end

  alias invoke pluck
end

class Array
  def to_ruby
    map {|f| "'#{f}'"}.join(', ')    
  end
  
  def map_with_index!
    each_with_index do |e, idx| self[idx] = yield(e, idx); end
  end

  def map_with_index(&block)
    dup.map_with_index!(&block)
  end


  # Returns an array with his hashes merged
  # Eg.
  # [{:hash1 => 1},{:hash2 => 2}].merge_hashes
  # Return [{:hash1 => 1, :hash2 => 2}]
  def merge_hashes
    hash = Hash.new
    self.select{ |h| h if !h.is_a?(Hash) || !hash.merge!(h) }  + (!hash.empty? ? [hash] : [])
  end

   def pluck!(method, *args)
    each_index { |x| self[x] = self[x].send method, *args }
  end

  alias invoke! pluck!

  def extract_options
    self.last.is_a?(::Hash) ? self.last : {}
  end

  def without_options
    self.last.is_a?(::Hash) && self.length > 1 ? self.values_at(0..-2) : self
  end

end

class Object
  #deep copy for a data structure, eg. Hash or Array
  #Authors GOTO Kentaro and Robert Feldt
  def deep_dup
    Marshal::load(Marshal.dump(self))
  end
end


class Hash
  
  # Returns a Hash that represents the difference between two Hashes who have Array values
  def deep_diff(hash)
    h1 = self.deep_dup
    h1.each do |k, v|
      h1_values = [*v]
      h2_values = [*hash[k]]

      old_values =  h1_values - h2_values
      new_values =  h2_values - h1_values

      h1_values = (old_values).uniq

      #Replace array wich has only one element by element value
      if h1_values.empty?
        h1.delete(k)
      elsif(h1_values.size == 1)
        h1[k]=h1_values.at(0)
      else
        h1[k] = h1_values
      end
    end
    h1
  end

  #convert Hash to Ldif syntax
  def to_ldif
    hash = self.stringify_keys
    ary = []
    hash.keys.sort.each {|attr|
      hash[attr].each {|val|
        #TODO Not Ruby 1.9 compliant
        ary << "#{attr}: #{val}" unless attr.to_sym == :dn
      }
    }

    block_given? and ary.each {|line| yield line}

    ary
  end

  # Replaces the hash with only the given keys.
  # Eg. {:last_name => 'Robert', :first_name => 'Bob', :age => 55}.from_keys(:last_name, :age)
  # Will return {:last_name => 'Robert', :age => 55}
  # Similar to ActiveSupport::CoreExtensions::Hash::Slice.slice! but with indifferent access bundles
  def from_keys(*keys)
    self.to_options!.reject { |k,v| !keys.collect{ |v| v.to_sym}.include?(k) }
  end
end

#class Symbol
#  include Comparable
#
#  #Fix #sort method for an Array of symbols who raised: undefined method `<=>' for :my_symbol:Symbol
#  #now [:c, :a, :d, :b, :e].sort
#  #return [:a, :b, :c, :d, :e]
#  def <=>(other)
#    self.to_s <=> other.to_s
#  end
#end

class Module
  alias_method(:const_missing_without_rails_app_path, :const_missing)
#  attr_accessor :rails_app_path
  @@rails_app_path = nil
  
  def self.rails_app_path=(value)
    @@rails_app_path = value
  end

  def self.rails_app_path
    @@rails_app_path
  end

  def const_missing(const_id)  
    return const_missing_without_rails_app_path(const_id) if @@rails_app_path.nil?

    begin
      loaded = true
      require_dependency("#{@@rails_app_path}/app/models/#{const_id.to_s.underscore}")
    rescue MissingSourceFile
      loaded = false
    end

    if loaded
      const_id.to_s.constantize
    else
      const_missing_without_rails_app_path const_id
    end

  end
end

class String
  # PHP's two argument version of strtr
  def strtr(replace_pairs)
    keys = replace_pairs.map {|a, b| a }
    values = replace_pairs.map {|a, b| b }
    self.gsub(
      /(#{keys.map{|a| Regexp.quote(a) }.join( ')|(' )})/
    ) { |match| values[keys.index(match)] }
  end

  #Convert specials chars to be compliant with Ldap filter
  def ldap_encode
    #self.strtr("*"=>"\\2a","\\"=>"\5c","NUL"=>"\\00","("=> "\\28",")"=>"\\29")
    self.strtr("$"=>"_24","("=> "_28",")"=>"_29")
  end

  #Restore specials chars from Ldap entry
  def ldap_decode
    self.strtr("_24"=>"$","_28"=> "(","_29"=>")")
  end

  SPECIALS_CHARS = {'˜' => '~', '‘’' => '\'', '«»„“”˝' => '"', '‒–—―‐' => '-', '…' => '...', '¡' => '!', '‼' => '!!',
    '¿' => '?', '‽' => '!?', '‹' => '<', '›' => '>', '♯' => '#', '⁄÷' => '/', '·' => '.',
    '¹' => '1', '²' => '2', '³' => '3',  '¼'=> '1/4', '½' => '1/2', '¾'=> '3/4', '×' => '*', '±' => '+/-', '∓' => '-/+',
    '№' => 'No', '™' => 'TM',
    'ÀÁÂÃÅĀĄĂΑ' => 'A', 'Ä' => 'Ae', 'àáâãåāąăαª' => 'a', 'ä' => 'ae', 'Æ' => 'AE', 'æ' => 'ae',
    'Β' => 'B', 'βϐ' => 'b', 'ÇĆČĈĊ©' => 'C', 'çćčĉċ' => 'c', 'ĎĐÐΔ' => 'D', 'ďđðδ' => 'd', 'ÈÉÊËĒĘĚĔĖΕΗ϶' =>'E',
    'èéêëēęěĕėεηϵ' => 'e', 'ƒ' => 'f', 'ĜĞĠĢΓ' => 'G', 'ĝğġģγϝ' => 'g', 'ĤĦ' => 'H',
    'ĥħ' => 'h', 'ÌÍÎÏĪĨĬĮİΙ' =>'I', 'ìíîïīĩĭįıι' =>'i', 'Ĳ' => 'IJ', 'Ĵ' => 'J',
    'ĵ' => 'j', 'ĶΚϘ' => 'K', 'Χ'=> 'KH', 'ķĸκϰϙ' => 'k', 'ϗ'=> 'kai', 'χ'=> 'kh',
    'ŁĽĹĻĿΛ' => 'L', 'łľĺļŀλ' => 'l', 'Μ' => 'M', 'μ'=>'m', 'ÑŃŇŅŊΝ' => 'N', 'ñńňņŉŋν' => 'n',
    'ÒÓÔÕØŌŐŎΟΩ' => 'O', 'Ö' => 'Oe', 'òóôõøōőŏωο°' => 'o', 'ö' => 'oe',    'Œ' => 'OE', 'œ' => 'oe',
    'Φ' => 'PH',  'Π' => 'Pi', 'Ψ' => 'PS',  'φϕ' => 'ph', 'πϖ' => 'pi', 'ψ' => 'ps', 'ŔŘŖℝ®Ρ' =>'R',
    'ŕřŗρϱ' =>'r', 'ŚŠŞŜȘΣϹϺ' => 'S', '§' => 'SS', 'śšşŝșσςϲϻ' => 's', 'ß' => 'ss', 'ŤŢŦȚΤ' => 'T', 'Θϴ' => 'TH',
    'ťţŧțτ' => 't', 'θϑ'=>'th', 'ÙÚÛŪŮŰŬŨŲΥϒϜ' =>'U', 'Ü' => 'Ue', 'ùúûūůűŭũųµυ' =>'u', 'ü' => 'ue',
    'Ŵ' => 'W', 'ŵ' => 'w', 'Ξ' => 'X', 'ξ' => 'x', 'ÝŶŸ' =>'Y', 'ýÿŷ' =>'y', 'ŹŽŻΖ' =>'Z', 'žżźζ' =>'z'}

  CURRENCY_CHARS = {'¤' => 'generic currency sign', '฿' => 'baht', '¢' => 'cent', '₡' => 'colón',
    '₵' => 'cedi', '₫' => 'dong', '€' => 'euro', 'ƒ' => 'florin', '₲' => 'guarani',
    '₴' => 'hryvnia', '₭' => 'kip', '₥' => 'mill', '₦' => 'naira', '₧' => 'peseta', '₱' => 'peso', '£' => 'pound',
    '﷼' => 'riyal', 'ރ' => 'rufiyaa', '₨' => 'rupee', '௹' => 'rupee', '৲ ৳' => 'rupee', '૱' => 'rupee',
    '₪' => 'new shekel', '₮' => 'tugrik', '₩' => 'won', '¥' => 'yen', '₳' => 'austral', '₠' => 'ECU',
    '₢' => 'cruzeiro', '₯' => 'drachma', '₣' => 'franc', '₤' => 'lira', 'ℳ' => 'mark', '₧' => 'peseta', '₰' => 'pfennig'}
  #'$' => 'dollar'# Skip dollar, beacause it's in ASCII table

#  ASCII_TABLE_CHARS = "!\"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

  # Replace every specials characters
  def replace_special_chars(replace_currency = false)
    string = self
    special_chars_table = SPECIALS_CHARS.merge(replace_currency ? CURRENCY_CHARS : {})
    special_chars_table.each do |key, value|
      string = string.gsub %r([#{key}]), value
    end
    string
  end

  def to_ascii(replace_currency = false)
    string = self.replace_special_chars(replace_currency)
    string.gsub(/[^\x20-\x7E]/i, '')
  end

end

# Generally useful methods
module RubySync
  module Utilities
    @@base_path=nil

    # If not already an array, slip into one
    def as_array o
      (o.instance_of? Array)? o : [o]
    end
    
    # Perform an action and rescue any exceptions thrown, display the exception with the specified text
    def with_rescue text
      begin
        yield
      rescue Exception => exception
        log.warn "#{text}: #{exception.message}"
        log.debug exception.backtrace.join("\n")
      end
    end       

    def dump_before
      []
    end

    def dump_after() []; end
    def perform_transform name, event, hint=""
      log.info event.to_yaml if dump_before.include?(name.to_sym)
      log.info "performing #{name}"
      call_if_exists name, event, hint
      event.commit_changes
      log.info event.to_yaml if dump_after.include?(name.to_sym)
    end
    
    def call_if_exists(method, event, hint="")
      result = nil
      if respond_to? method
        with_rescue("#{method} #{hint}") {result = send method, event}
      else
        log.debug "No #{method}(event) method, continuing #{hint}"
      end
      return result
    end

    def log_progress last_action, event, hint=""
      log.info "Result of #{last_action}: #{hint}\n" + YAML.dump(event)
    end
    
    
    # Ensure that a given path exists as a directory
    def ensure_dir_exists paths
      as_array(paths).each do |path|
        raise Exception.new("Can't create nil directory") unless path
        if File.exist? path
          unless File.directory? path
            raise Exception.new("'#{path}' exists but is not a directory")
          end
        else
          log.info "Creating directory '#{path}'"
          FileUtils.mkpath path
        end
      end
    end
    
    def pipeline_called name
      begin
        something_called name, "pipeline"
      rescue
        log.error "Pipeline named '#{name}' not found."
        nil
      end
    end
    
    
    def connector_called name, message=nil
      begin
        something_called name, "connector"
      rescue
        message ||= "Connector named '#{name}' not found."
        log.error message
        nil
      end
    end

    # Locates and returns an instance of a class for
    # the given name.
    def something_called name, extension, message=nil
      klass = class_called(name, extension, message) and klass.new()
    end

    def class_called name, extension, message=nil
      class_for_name(class_name_for(name, extension), message)
    end
      
    def class_for_name(name, message=nil)
      eval(name)
    rescue Exception => e
      message ||= "Unable to find class called '#{name}'"
      log.error message
      log.error e.message#debug
      nil
    end

    def class_name_for name, extension
      "#{name.to_s}_#{extension}".camelize
    end
    
    # Ensure that path is in the search path
    # prepends it if it's not
    def include_in_search_path path
      path = File.expand_path(path)
      $:.unshift path unless $:.include?(path)
    end
    
    # Return the base_path
    ::Kernel.send :define_method, :base_path do
      @@base_path = find_base_path unless @@base_path
      @@base_path
    end

    # Locate a configuration directory by checking the current directory and
    # all of it's ancestors until it finds one that looks like a rubysync configuration
    # directory.
    # Returns false if no suitable directory was found
    ::Kernel.send :define_method, :find_base_path do
      bp = File.expand_path(".")
      last = nil
      # Keep going up until we start repeating ourselves
      while File.directory?(bp) && bp != last && bp != "/"
        return bp if File.directory?("#{bp}/pipelines") &&
          File.directory?("#{bp}/connectors")
        last = bp
        bp = File.expand_path("#{bp}/..")
      end
      return false
    end
       
    
    def get_preference(name, file_name=nil)
      class_name ||= get_preference_file
    end
    
    def set_preference(name)
      
    end
    
    def get_preference_file_path name
      dir = "#{ENV[HOME]}/.rubysync"
      Dir.mkdir(dir)
      "#{dir}#{file}"
    end
    
    # Performs the given operations on the given record. The record is a
    # Hash in which each key is a field name and each value is an array of
    # values for that field.
    # Operations is an Array of RubySync::Operation objects to be performed on the record.
    def perform_operations operations, record={}, options={}
      subjects = options[:subjects]
      operations.each do |op|
        unless op.instance_of? RubySync::Operation
          log.warn "!!!!!!!!!!  PROBLEM, DUMP FOLLOWS: !!!!!!!!!!!!!!"
          p op
        end
        key = op.subject
        next if subjects and !subjects.include?(key)
        case op.type
        when :add
          if record[key]
            existing = as_array(record[key])
            next if existing == op.values # already same so ignore
            (existing & op.values).empty? or
              raise "Attempt to add duplicate elements to #{name}"
            record[key] =  existing + op.values
          else
            record[key] = op.values
          end
        when :replace
          record[key] = op.values
        when :delete
          if record[key]
            unless op.value
              record.delete(op.subject)
            else
              record[key] -= op.values
            end
          end
        else
          raise Exception.new("Unknown operation '#{op.type}'")
        end
      end
      return record
    end

      
    # Filter operations to eliminate those that would have
    # no effect on the record. Returns the resulting array
    # of operations.
    def effective_operations operations, record={}
      effective = []
      operations.each do |op|
        existing = as_array(record[op.subject] || [])
        case op.type
        when :add
          if existing.empty?
            effective << op
          else
            next if existing == op.values # already same so ignore
            effective << Operation.replace(op.subject, op.values)
          end
        when :replace
          if existing.empty?
            effective << Operation.add(op.subject, op.values)
          else
            next if existing == op.values
            effective << op
          end
        when :delete
          unless op.value
            effective << op if record[op.subject]
          else
            targets = op.values & existing
            targets.empty? or effective << Operation.delete(op.subject, targets)
          end
        else
          raise Exception.new("Unknown operation '#{op.type}'")
        end
      end
      effective
    end
 
  end
end
