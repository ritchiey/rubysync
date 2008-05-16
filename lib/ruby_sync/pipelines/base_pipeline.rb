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

require 'active_support'
require 'ruby_sync/util/metaid'
require 'ruby_sync/util/utilities'
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
      
      array_option :dump_before, :dump_after
      dump_before HashWithIndifferentAccess.new
      dump_after HashWithIndifferentAccess.new
      
      def initialize
        @delay = 5
      end
      
      def name
        self.class.name
      end
      
      def self.client(connector_name, options={})
	options = HashWithIndifferentAccess.new(options)
        class_name = RubySync::Connectors::BaseConnector.class_name_for(connector_name)
        options[:name] ||= "#{self.name}(client)"
        options[:is_vault] = false
        class_def 'client' do
          @client ||= eval(class_name).new(options)
        end
      end
      
      def self.vault(connector_name, options={})
	options = HashWithIndifferentAccess.new(options)
        class_name = RubySync::Connectors::BaseConnector.class_name_for(connector_name)
        options[:name] ||= "#{self.name}(vault)"
        options[:is_vault] = true
        class_def 'vault' do
          unless @vault
            @vault = eval(class_name).new(options)
            @vault.pipeline = self
          end
          @vault
        end
      end
      

      def self.in_transform(&blk) deprecated_event_method :in_transform, :in_event_transform, &blk; end
      def self.in_event_transform(&blk) event_method :in_event_transform,&blk; end
      def self.in_command_transform(&blk) event_method :in_command_transform,&blk; end
      def self.out_transform(&blk) deprecated_event_method :out_transform, :out_event_transform, &blk; end
      def self.out_event_transform(&blk) event_method :out_event_transform,&blk; end
      def self.out_command_transform(&blk) event_method :out_command_transform,&blk; end
      def self.in_match(&blk) event_method :in_match,&blk; end
      def self.out_match(&blk) event_method :out_match,&blk; end
      def self.in_create(&blk) event_method :in_create,&blk; end
      def self.out_create(&blk) event_method :out_create,&blk; end
      def self.in_place(&blk) event_method :in_place,&blk; end
      def self.out_place(&blk) event_method :out_place,&blk; end

      def self.event_method name,&blk
        define_method name do |event|
          event.instance_eval(&blk)
        end
      end

      def self.deprecated_event_method name, replacement, &blk
	log.warn "'#{name}' has been deprecated. Use '#{replacement}' instead."
	event_method(replacement, &blk)
      end


      def in_match(event)
        log.debug "Default matching rule - vault[in_place] exists?"
	if vault.respond_to?('[]')
          path = in_place(event) 
	  if path
	    log.debug "Checking for object at '#{path}' on vault."
	    vault[path] and path
	  end
	else
	  log.debug "Vault doesn't support random access - no match"
	  nil
	end
      end
      
      def out_match(event)
        log.debug "Default matching rule - client[out_place] exists?"
        path = out_place(event)
        client.respond_to?('[]') and client[path] and path
      end
      
      # Override to restrict creation on the client
      def default_create event
        log.debug "Create allowed through default rule"
        true
      end
      alias_method :in_create, :default_create
      alias_method :out_create, :default_create
      
      # Override to modify the target path for creation on the client
      def default_place(event)
        log.debug "Default placement: same as source_path"
        event.source_path
      end
      alias_method :in_place, :default_place
      alias_method :out_place, :default_place
      
      def in_place_transform(event)
        event.target_path = in_place(event)
      end
      
      def out_place_transform(event)
        event.target_path = out_place(event)
      end
      
      def perform_transform name, event, hint=""
	log.info event.to_yaml if dump_before.include?(name.to_sym)
	log.info "Performing #{name}"
        call_if_exists name, event, hint
        event.commit_changes
	log.info event.to_yaml if dump_after.include?(name.to_sym)
      end
            
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
        return unless allowed_in
        log.debug "Running #{name} 'in' pipeline once"
        client.once_only = true
        client.start {|event| in_handler(event)}
      end
      
      # Execute the out pipe once and then return
      def run_out_once
        return unless allowed_out
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
      # Note: The client can't really know whether the event is an add or a modify because it doesn't store
      # the association.
      def in_handler(event)
        event.target = @vault
        event.retrieve_association(association_context)

        log.info "Processing incoming #{event.type} event "+event.hint
        perform_transform :in_filter, event, event.hint

        perform_transform :in_event_transform, event, event.hint
            
        associated_entry = nil
        unless event.type == :disassociate
          associated_entry = vault.find_associated(event.association) if event.associated?
          unless associated_entry
            match = in_match(event)
            if match
              log.info("Matching entry found for unassociated event: '#{match}'. Creating association.")
              event.association = Association.new(association_context, event.source_path)
              vault.associate event.association, match
              associated_entry = vault[match]
            else
              log.info "No match found for unassociated entry."
            end
          end          
        end

        if associated_entry
          if event.type == :add
	    log.info "Associated entry in vault for add event. Converting to modify"
            event.convert_to_modify associated_entry, allowed_in
          end
        elsif event.type == :modify
	  log.info "No associated entry in vault for modify event. Converting to add"
	  event.convert_to_add 
        end

	perform_transform :in_command_transform, event, event.hint

        case event.type
        when :add
          if in_create(event)
            perform_transform :in_place_transform, event, event.hint
      	    log.info "Create on vault allowed. Placing at #{event.target_path}"
          else
      	    log.info "Create rule disallowed creation"
            log.info "---\n"; return
          end
        when :modify
          event.merge(associated_entry)
        else
          unless event.associated?
      	    log.info "No associated entry in vault for #{event.type} event. Dropping"
            log.info "---\n"; return
          end
        end

        with_rescue("#{vault.name}: Processing command") {vault.process(event)}
        log.info "---\n"
        
      end
      
      # Called by the 'vault' connector in the 'out' thread to process events generated by the vault.
      def out_handler(event)
        event.target = @client
        event.retrieve_association(association_context)

        log.info "Processing outgoing #{event.type} event "+ event.hint
        perform_transform :out_filter, event, event.hint
        perform_transform :out_event_transform, event, event.hint

        associated_entry = nil
        unless event.type == :disassociate
          associated_entry = client.entry_for_own_association_key(event.association.key) if event.associated?
          unless associated_entry
            match = out_match(event)
            if match
              log.info("Matching entry found for unassociated event: '#{match}'. Creating association.")
              event.association = Association.new(association_context, match)
              vault.associate event.association, event.source_path
              associated_entry = client[match]
            end
          end          
        end
            
        if associated_entry
          if event.type == :add
	    log.info "Associated entry in client for add event. Converting to modify"
            event.convert_to_modify(associated_entry)
          end
        elsif event.type == :modify
	  log.info "No associated entry in client for modify event. Converting to add"
	  event.convert_to_add 
        end

        perform_transform :out_command_transform, event, event.hint

        case event.type
        when :add
          if out_create(event)
            perform_transform :out_place_transform, event, event.hint
      	    log.info "Create on client allowed. Placing at #{event.target_path}"
          else
      	    log.info "Create rule disallowed creation"
            log.info "---\n"; return
          end
        when :modify
          event.merge(associated_entry)
        else
          unless event.associated?
      	    log.info "No associated entry in client for #{event.type} event. Dropping"
            log.info "---\n"; return
          end
        end

        with_rescue("#{client.name}: Processing command") {client.process(event)}
        log.info "---\n"
        
      end
      
      
      # Called by the identity-vault connector in the 'out' thread to process events generated
      # by the identity vault.
      #       def out_handler(event)
      #         event.target = @client
      #         event.retrieve_association(association_context)
      #         event.convert_to_modify if event.associated? and event.type == :add
      # 
      #         hint = "(path=#{event.source_path} #{vault.name} => #{client.name})"
      #         log.info "Processing out-going #{event.type} event #{hint}"
      #         #log.info YAML.dump(event)
      #         unless out_event_filter event
      #           log.info "Disallowed by out_event_filter"
      #           log.info "---\n"; return
      #         end
      # 
      #         # Remove unwanted attributes
      #         perform_transform :out_filter, event
      # 
      #         unless event.associated?
      #           log.info "no association"
      #           if [:delete, :disassociate].include? event.type
      #             log.info "#{name}: No action for #{event.type} of unassociated entry"
      #             log.info "---\n"; return
      #           end
      #         end
      # 
      #         if event.type == :modify
      #           unless event.associated? and client.has_entry_for_key?(event.association.key)
      #           log.info "Can't find associated client record so converting modify to add"
      #           event.convert_to_add
      #         end
      #       end
      # 
      #             if event.type == :add
      #               match = out_match(event) 
      #               log.info "Attempting to match"
      #               if match # exactly one event record on the client matched
      #                 log.info "Match found, merging"
      #                 perform_transform :out_place, event
      #                 event.merge(match)
      #                 association = Association.new(self.association_context, match.source_path)
      #                 vault.associate asssociation, event.source_path
      #                 log.info "---\n"; return
      #               end
      #               log.info "No match found, creating"
      #               unless out_create(event)
      #     log.info "Creation denied by create rule"
      #                 log.info "---\n"; return
      #   end
      #               perform_transform :out_place_transform, event
      #       log.info "Placing new entry at #{event.target_path}"
      #             end
      # 
      #             perform_transform :out_transform, event
      #             association_key = nil
      #             with_rescue("#{client.name}: Processing command") do
      #               association_key = client.process(event)
      #             end
      #             if association_key
      #               association = Association.new(association_context, association_key)
      #               with_rescue("#{client.name}: Storing association #{association} in vault") do
      #                 vault.associate(association, event.source_path)
      #               end
      # else
      #   log.info "Client didn't return an association key"
      #             end
      #           end
      
      
      
      # The context for all association keys used by this pipeline.
      # By default, defer to the client
      def association_context
        @client.association_context
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
      
      
      def in_filter(event)
	allowed_in == [] or event.drop_all_but_changes_to(allowed_in || [])
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
      
      def out_filter(event)
	allowed_out == [] or event.drop_all_but_changes_to(allowed_out || [])
      end



    end
  end
end
