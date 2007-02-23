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

lib_path = File.dirname(__FILE__) + '/../..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync/util/metaid'
require 'yaml'


module RubySync
  module Pipelines
    
    # This pipeline is the base for those that synchronize content bi-directionally between
    # two datastores. These are commonly used for synchronizing identity information between
    # directories.
    #
    # One of the data-stores is called the identity-vault. This is generally the central repository for
    # identity information (typically, an LDAP server or relational database).
    # We'll call  the other data-store the client for want of a better term. This is could be anything
    # that an EndPoint has been written for (an LDAP server, a text file, an application, etc).
    #
    # We refer to the flow of events from the client to the identity-vault as incoming and those from
    # the identity vault to the client as out-going. Methods in this class prefixed with 'in_' or 'out_'
    # work on the incoming or outgoing flows respectively.
    class BasePipeline

      include RubySync::Utilities
      
      def initialize
      end
      
      def name
        self.class.name
      end

      def self.client(connector_name, options={})
        options[:name] ||= "#{self.name}(client)"
        class_name = "::" + "#{connector_name}_connector".camelize
        options[:is_vault] = false
        class_def 'client' do
          @client ||= eval(class_name).new(options)
        end
      end


      def self.vault(connector_name, options={})
        class_name = "::" + "#{connector_name}_connector".camelize
        options[:name] ||= "#{self.name}(vault)"
        options[:is_vault] = true
        class_def 'vault' do
          @vault ||= eval(class_name).new(options)
        end
      end
      
      def self.map_client_to_vault mappings
        class_def 'client_to_vault_map' do
          @client_to_vault_map ||= mappings
        end
        class_def 'vault_to_client_map' do
          @vault_to_client_map ||= mappings.invert
        end
      end

      # Called by the identity-vault connector in the 'out' thread to process events generated
      # by the identity vault.
      def out_handler(event)
        hint = " (#{vault.name} => #{client.name})"
        log.info "Processing out-going #{event.type} event #{hint}"
        log.info YAML.dump(event)
        return unless out_event_filter event

        if !event.association_key and [:delete, :remove_association].include? event.type
          log.info "#{name}: No action for #{event.type} of unassociated entry"
          log.info YAML.dump(event)
          return
        end

        if event.type == :modify and !event.association
          event.convert_to_add
        end

        if event.type == :add
          match = out_match(event, client) # exactly one event record on the client matched
          log.info "Attempting to match"
          if match
            log.info "Match found, merging"
            event.merge(match)
            vault.associate_with_foreign_key(match.src_path, event.source_path)
            return
          else
            log.info "No match found."
          end
          
          if out_create(event)
            call_if_exists :out_place, event
          end
        end

        call_if_exists :out_map_schema, event
        call_if_exists :out_transform, event
        association_key=nil
        with_rescue("#{client.name}: Processing command") do
          association_key = client.process(event)
        end
        if association_key
          with_rescue("#{client.name}: Storing association key #{association_key} in vault") do
            vault.associate_with_foreign_key(association_key, event.source_path)
          end
        end
      end
      
      # Override to map schema from vault namespace to client namespace
      # def out_map_schema event
      # end

      # Combines the id of this pipeline with the given key
      # to provide a unique association key to be stored in the
      # identity vault
      def association_key_for(key)
        "#{name}:#{key}"
      end
      
      # Override to implement some kind of matching
      def out_match event, client
        log.debug "Default matching rule - no match"
        false
      end

        # Override to restrict creation on the client
        def out_create event
          log.debug "Create allowed through default rule"
          true
        end
        
        # Override to restrict creation on the vault
        def in_create event
          log.debug "Create allowed through default rule"
          true
        end
      
        # Override to modify the target path for creation on the client
        def out_place(event)
          log.debug "Default placement rule target_path = source_path"
          event.target_path = event.source_path
        end

        # Override to modify the target path for creation in the vault
        def in_place(event)
          log.debug "Default placement rule target_path = source_path"
          event.target_path = event.source_path
        end

      
      # Transform the out-going event before the client receives it
      # def out_transform(event)
      # end
      
      # Execute the pipeline once then return.
      # TODO Consider making this run in and out simultaneously
      def run_once
        log.info "Running #{name} pipeline once"
        run_in_once
        run_out_once
      end
      
      # Execute the in pipe once and then return
      def run_in_once
        log.info "Running #{name} 'in' pipeline once"
        client.once_only = true
        client.start {|event| in_handler(event)}
      end
      
      # Execute the out pipe once and then return
      def run_out_once
        log.info "Running #{name} 'out' pipeline once"
        vault.once_only = true
        vault.start {|event| out_handler(event)}
      end
      
      
      # Override to process the event generated by the publisher before any other processing is done.
      # Return false to veto the event.
      def out_event_filter(event);  true;  end
      
      # Called by the 'in' connector in the 'in' thread to process events generated by the client.
      def in_handler(event)
        hint = " (#{client.name} => #{vault.name})"
        log.info "Processing incoming #{event.type} event"+hint
        log.info YAML.dump(event)
        call_if_exists :in_map_schema, event, hint
        call_if_exists :in_transform, event, hint
        call_if_exists :in_filter, event, hint
        
        if event.type == :modify
          unless event.association_key and (associated = vault.find_associated(event))
            event.convert_to_add
          end
        end
        
        if event.type == :add
          match = in_match(event, vault) # exactly one event record in the vault matched
          if match
            event.merge(match)
            return
          end
          
          if in_create(event)
            call_if_exists :in_place, event, hint
          end
        end
        with_rescue("#{vault.name}: Processing command") {vault.process(event)}
        
      end


      def in_match(event, client)
        log.debug "Default match returning false"
        return false
      end

      # If client_to_vault_map is defined (usually by map_client_to_vault)
      # then fix up the contents of the payload to refer to the fields by
      # the names in the vault namespace
      def in_map_schema event
        return unless defined? client_to_vault_map
        return unless defined? event.payload
        event.payload.each do |op|
          op[1] = client_to_vault_map[op[1]] || op[1]
        end
      end

      
     
      # Override to perform whatever transformation on the event is required
      #def in_transform(event); event; end
      
      # Convert fields in the incoming event to those used by the identity vault
      #def in_map_schema(event); end

     # Specify which fields will be allowed through the incoming filter
     # If nil (the default), all fields are allowed. 
     def self.allow_in *fields
       class_def 'allowed_in' do
         fields
       end
     end
 
     # default allowed_in in case allow_in doesn't get called
     def allowed_in; nil; end
 
     # Default method for allowed_in. Override by calling allow_in
     #def allowed_in; false; end
     def in_filter(record)
        if allowed_in
          filtered={}
          allowed_in.each {|key| filtered[key] = record[key] if record[key]}
          return filtered
        else
          record
        end
      end
    end
  end
end


