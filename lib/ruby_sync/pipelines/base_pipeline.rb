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

lib_path = File.dirname(__FILE__) + '/../..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'active_support'
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
      
      attr_accessor :delay    # delay in seconds between checking connectors
      
      def initialize
        @delay = 5
      end
      
      def name
        self.class.name
      end
      
      def self.client(connector_name, options={})
        class_name = RubySync::Connectors::BaseConnector.class_name_for(connector_name)
        options[:name] ||= "#{self.name}(client)"
        options[:is_vault] = false
        class_def 'client' do
          @client ||= eval("::#{class_name}").new(options)
        end
      end
      
      def self.vault(connector_name, options={})
        class_name = RubySync::Connectors::BaseConnector.class_name_for(connector_name)
        options[:name] ||= "#{self.name}(vault)"
        options[:is_vault] = true
        class_def 'vault' do
          @vault ||= eval("::" + class_name).new(options)
        end
      end
      
      def self.map_client_to_vault mappings
        remove_method :client_to_vault_map if method_defined? :client_to_vault_map
        class_def 'client_to_vault_map' do
          unless @client_to_vault_map
            @client_to_vault_map = {}
            mappings.each {|k,v| @client_to_vault_map[k.to_s] = v.to_s}
          end
          @client_to_vault_map
        end
        unless method_defined? :vault_to_client_map
          class_def 'vault_to_client_map' do
            @vault_to_client_map ||= client_to_vault_map.invert
          end
        end
      end
      
      def self.map_vault_to_client mappings
        remove_method :vault_to_client_map if method_defined? :vault_to_client_map
        class_def 'vault_to_client_map' do
          unless @vault_to_client_map
            @vault_to_client_map = {}
            mappings.each {|k,v| @vault_to_client_map[k.to_s] = v.to_s}
          end
          @vault_to_client_map
        end
        unless method_defined? :client_to_vault_map
          class_def 'client_to_vault_map' do
            @client_to_vault_map ||= vault_to_client_map.invert
          end
        end
      end
      
      def self.out_transform &blk
        define_method :out_transform do |event|
          event.meta_def :transform, &blk
          event.transform
        end
      end
      
      def self.in_transform &blk
        define_method :in_transform do |event|
          event.meta_def :transform, &blk
          event.transform
        end
      end
      
      
      # Called by the identity-vault connector in the 'out' thread to process events generated
      # by the identity vault.
      def out_handler(event)

        event.retrieve_association(association_context)
        event.convert_to_modify if event.associated? and event.type == :add
        
        hint = " (#{vault.name} => #{client.name})"
        log.info "Processing out-going #{event.type} event #{hint}"
        log.info YAML.dump(event)
        return unless out_event_filter event
        
        # Remove unwanted attributes
        perform_transform :out_filter, event

        unless event.associated?
          if [:delete, :remove_association].include? event.type
            log.info "#{name}: No action for #{event.type} of unassociated entry"
            log.info YAML.dump(event)
            return
          end
        end

        if event.type == :modify
          unless event.associated? and client.has_entry_for_key?(event.association.key)
            event.convert_to_add
          end
        end

        if event.type == :add
          match = out_match(event) 
          log.info "Attempting to match"
          if match # exactly one event record on the client matched
            log.info "Match found, merging"
            event.merge(match)
            association = Association.new(self.association_context, match.src_path)
            vault.associate asssociation, event.source_path
            return
          end
          log.info "No match found, creating"
          return unless out_create(event)
          perform_transform :out_place, event
        end
        
        perform_transform :out_map_schema, event
        perform_transform :out_transform, event
        association_key = nil
        with_rescue("#{client.name}: Processing command") do
          association_key = client.process(event)
        end
        if association_key
          association = Association.new(association_context, association_key)
          with_rescue("#{client.name}: Storing association #{association} in vault") do
            vault.associate(association, event.source_path)
          end
        end
      end
      
      # Override to map schema from vault namespace to client namespace
      # def out_map_schema event
      # end
      
      # Override to implement some kind of matching
      def out_match event
        log.debug "Default matching rule - source path exists on client?"
        client.respond_to?('[]') and client[event.source_path]
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
      
      def perform_transform name, event, hint=""
        call_if_exists name, event, hint
        event.commit_changes
        log_progress name, event, hint
      end
      
      # Transform the out-going event before the client receives it
      # def out_transform(event)
      # end
      
      # Execute the pipeline once then return.
      def run_once
        log.info "Running #{name} pipeline once"
        started
        run_in_once
        run_out_once
        stopped
      end
      
      def started
        client.started
        vault.started
      end
      
      def stopped
        client.stopped
        vault.stopped
      end
      
      # Execute the in pipe once and then return
      def run_in_once
        log.debug "Running #{name} 'in' pipeline once"
        client.once_only = true
        client.start {|event| in_handler(event)}
      end
      
      # Execute the out pipe once and then return
      def run_out_once
        log.debug "Running #{name} 'out' pipeline once"
        vault.once_only = true
        vault.start {|event| out_handler(event)}
      end
      
      def start
        log.info "Starting #{name} pipeline"
        @running = true
        trap("SIGINT") {self.stop}
        started
        while @running
          run_in_once
          run_out_once
          sleep delay
        end
        stopped
        log.info "#{name} stopped."
      end
      
      def stop
        log.info "#{name} stopping..."
        @running = false
        Thread.main.run # i thought this would wake the thread from its sleep
        # but it seems to have no effect.
      end
      
      # Override to process the event generated by the publisher before any other processing is done.
      # Return false to veto the event.
      def out_event_filter(event);  true;  end
      
      # Called by the 'in' connector in the 'in' thread to process events generated by the client.
      def in_handler(event)
        event.retrieve_association(association_context)        

        hint = " (#{client.name} => #{vault.name})"
        log.info "Processing incoming #{event.type} event"+hint
        log.info YAML.dump(event)
        perform_transform :in_map_schema, event, hint
        perform_transform :in_transform, event, hint
        perform_transform :in_filter, event, hint
        
        # The client can't really know whether its an add or a modify because it doesn't store
        # the association.
        if event.type == :modify
          event.convert_to_add unless event.associated? and vault.find_associated(event.association)
        elsif event.type == :add and event.associated? and vault.find_associated(event.association)
          event.convert_to_modify
        end
        
        if event.type == :add
          match = in_match(event) # exactly one event record in the vault matched
          if match
            event.merge(match)
            return
          end
          
          if in_create(event)
            perform_transform :in_place, event, hint
          else
            return
          end
        end
        
        with_rescue("#{vault.name}: Processing command") {vault.process(event)}
        
      end
      
      # The context for all association keys used by this pipeline.
      # By default, defer to the client
      def association_context
        @client.association_context
      end
      
      def in_match event
        log.debug "Default match rule - source path exists in vault"
        vault.respond_to?('[]') and vault[event.source_path]
      end
      
      # If client_to_vault_map is defined (usually by map_client_to_vault)
      # then fix up the contents of the payload to refer to the fields by
      # the names in the vault namespace
      def in_map_schema event
        map_schema event, client_to_vault_map if respond_to? :client_to_vault_map
      end
      
      def out_map_schema event
        map_schema event, vault_to_client_map if respond_to? :vault_to_client_map
      end
      
      def map_schema event, map
        return unless map and event.payload
        event.payload.each do |op|
          op.subject = map[op.subject] || op.subject if op.subject
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
          fields.map {|f| f.to_s}
        end
      end
      
      # default allowed_in in case allow_in doesn't get called
      def allowed_in; nil; end
      
      # Default method for allowed_in. Override by calling allow_in
      #def allowed_in; false; end
      def in_filter(event)
        if allowed_in
          event.drop_all_but_changes_to allowed_in
        else
          event
        end
      end


      # Specify which fields will be allowed through the incoming filter
      # If nil (the default), all fields are allowed. 
      def self.allow_out *fields
        class_def 'allowed_out' do
          fields.map {|f| f.to_s }
        end
      end
      
      # default allowed_out in case allow_out doesn't get called
      def allowed_out; nil; end
      
      # Default method for allowed_out. Override by calling allow_in
      #def allowed_out; false; end
      def out_filter(event)
        if allowed_out
          event.drop_all_but_changes_to allowed_out
        else
          event
        end
      end


    end
  end
end
