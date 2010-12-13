#!/usr/bin/env ruby
#
#  Copyright (c) 2009 Nowhere Man
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


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'ruby_sync/connectors/ldap_connector'

require 'net/ldif_support'
$VERBOSE = false
require 'net/ldap'
#$VERBOSE = true

RUBYSYNC_CHANGELOG_CLASS = "rubySyncChangeLogEntry"
RUBYSYNC_DUMP_ENTRY_ATTRIBUTE = "rubySyncDumpEntry"
RUBYSYNC_CONTEXT_ATTRIBUTE = "rubySyncContext"
RUBYSYNC_SOURCE_INFO_ATTRIBUTE = "rubySyncSourceInfo"

module RubySync::Connectors

  module LdapChangelogRubyChange
    #option :username, :search_filter, :host, :search_base, :port, :changelog_dn, :password, :bind_method

    def each_change(&blk)
      #      unless @last_sync == nil and @last_sync.split(",")[0] == self.association_context
      #        restore_last_sync_state
      #      end
      #      first = true
      with_ldap do |ldap|
        log.debug "@last_change_number = #{@last_change_number}"

        filter = Net::LDAP::Filter.ge("changenumber", @last_change_number.to_i.to_s)

        @full_refresh_required = false
        ldap.search :base => changelog_dn, :filter => filter do |change|
          change_number = change.changenumber[0].to_i
          if change_number > @last_change_number.to_i
            log.info("#{name}: change_number > @last_change_number")
            if @last_change_number.to_i == 0 && change_number > (@last_change_number.to_i + 1)
              log.warn "#{name}: ChangeLog entries should start with changeNumber = 1 but was #{change_number}, check your LDAP indexes"
            end
#            context = change.send(RUBYSYNC_CONTEXT_ATTRIBUTE.downcase)[0]
#            if context == self.association_context
            # TODO: A proper DN object would be nice instead of string manipulation
            target_search_path = self.class.path_cookie.gsub(/\s*,\s*/,',')
            if respond_to?(:search_base) && target_search_path =~ /#{search_base}$/oi
              log.info("#{name}: Read the new changeLogEntry")
#              change_type = change.changetype[0]
#              if change_type.to_sym == :delete
#                 event = RubySync::Event.delete(self, change.send(RUBYSYNC_SOURCE_INFO_ATTRIBUTE)[0] )
#              elsif change_type.to_sym == :modify
#                change[RUBYSYNC_DUMP_ENTRY_ATTRIBUTE] = change['changes']
#                event = event_for_changelog_entry(change)
#              else
              event = event_for_changelog_entry(change)
#              end

              yield event
              @last_change_number = change_number
              update_last_sync_state
            end
          end
          #          end
        end
      end

      # scan existing entries to see if any are new or modified
      save_changelog_entries(&blk)

    end

    # Called by start() before first call to each_change or each_entry
    def sync_started(&blk)
      # scan changelog entries to find deleted only if track_deleted option is true
      #  or a number who manage probability that the delete_changelog_entries method is called
      if @last_change_number > 0 && respond_to?(:track_deleted) && track_deleted &&
       (!track_deleted.is_a?(Numeric) || rand(100) < track_deleted.to_i.abs )
        log.warn "#{name}: #delete_changelog_entries called"
        delete_changelog_entries(&blk)
      end
    end

    # Dummy method, because we don't have to skip changelog entries with software LDAP changelog
    def skip_existing_changelog_entries; end

    # Compare current entry with last entry store in changeLogEntry and return a ldif_entry
    def compare_changes(path, entry, change)
      
      ldif_entry = ''
      if change.attribute_names.include?(:changes) or change.attribute_names.include?(RUBYSYNC_DUMP_ENTRY_ATTRIBUTE.downcase.to_sym)

        # using RUBYSYNC_DUMP_ENTRY_ATTRIBUTE only for change_type :modify
        changes_attribute = ( change.changetype[0].to_sym == :add )? :changes : RUBYSYNC_DUMP_ENTRY_ATTRIBUTE.downcase.to_sym

        last_entry = Net::LDIF.parse("dn: #{path}\nchangetype: add\n#{change.send(changes_attribute)[0]}")[0].data
        raise Exception.new("#{name}: Wrong type for last entry or current entry") if !last_entry.respond_to?(:deep_diff) && !entry.respond_to?(:deep_diff)

        diff_attributes = last_entry.full_diff(entry)

        # Deleting or replacing attributes only if the lastest change has been done by the actual client/vault
        if change.send(RUBYSYNC_CONTEXT_ATTRIBUTE.downcase)[0] == self.association_context

          diff_attributes[:deleted].each do |key|
            diff_attributes[:old][key].each do |value|
              if Net::LDIF.binary_value?(value)
                ldif_entry = ldif_entry + "delete: #{key}\n#{key}:: #{value}\n-\n"
              else
                ldif_entry = ldif_entry + "delete: #{key}\n#{key}: #{value}\n-\n"
              end
              log.debug("#{name}: remove attribute #{key}: #{value}")
            end
          end

          diff_attributes[:replaced].each do |key|
            if entry.symbolize_keys[key].is_a?(Array) or last_entry.symbolize_keys[key].is_a?(Array)
              diff_attributes[:old][key].each do |value|
                if Net::LDIF.binary_value?(value)
                   ldif_entry = ldif_entry + "delete: #{key}\n#{key}:: #{value}\n-\n"
                else
                  ldif_entry = ldif_entry + "delete: #{key}\n#{key}: #{value}\n-\n"
                end
                log.debug("#{name}: in replace : remove attribute #{key}: #{value}")
              end
  
              diff_attributes[:new][key].each do |value|
                if Net::LDIF.binary_value?(value)
                  ldif_entry = ldif_entry + "add: #{key}\n#{key}:: #{value}\n-\n"
                else
                  ldif_entry = ldif_entry + "add: #{key}\n#{key}: #{value}\n-\n"
                end
                log.debug("#{name}: in replace : add attribute #{key}: #{value}")
              end
            else
              value = diff_attributes[:new][key]
              if Net::LDIF.binary_value?(value)
                ldif_entry = ldif_entry + "replace: #{key}\n#{key}:: #{value}\n-\n"
              else
                ldif_entry = ldif_entry + "replace: #{key}\n#{key}: #{value}\n-\n"
              end
              log.debug("#{name}: replace attribute #{key}: #{value}")
            end
          end
        end

        diff_attributes[:added].each do |key|
          diff_attributes[:new][key].each do |value|
            if Net::LDIF.binary_value?(value)
              ldif_entry = ldif_entry + "add: #{key}\n#{key}:: #{value}\n-\n"
            else
              ldif_entry = ldif_entry + "add: #{key}\n#{key}: #{value}\n-\n"
            end
            log.debug("#{name}: add attribute #{key}: #{value}")
          end
        end

        log.debug("#{name}: ldif changelog entry is empty") if ldif_entry.empty?
        ldif_entry
      else
        raise Exception.new("#{name}: Invalid changelog entry, 'changes' or '#{RUBYSYNC_DUMP_ENTRY_ATTRIBUTE}' attributes are empty")#No changes found
      end

    end

    # Override this method if you want to add/modify/delete attributes of the entry
    def transform_entry(path, entry)
      entry
    end

    def save_changelog_entries(&blk)
      each_entry do |path, entry|

        if path
          entry = transform_entry(path, entry, &blk)
          entry.delete_if {|key, value| value.blank? }
          entry.dasherize_keys!.stringify_values!
          with_ldap do |ldap|
            ldif_entry = ''

            filter = Net::LDAP::Filter.eq(RUBYSYNC_SOURCE_INFO_ATTRIBUTE, path) & Net::LDAP::Filter.eq(:objectclass, RUBYSYNC_CHANGELOG_CLASS)

            if !(ldap_results=ldap.search(:base => changelog_dn, :filter => filter)) || ldap_results.empty?
              type='add'# Create entry
            else
              change = ldap_results.sort_by { |ldap_result| ldap_result[:changenumber][0].to_i }.last

              case change.changetype[0].to_sym
              when :delete
                type='add'# Recreate entry
              when :add, :modify
                type = 'modify'# Update existing entry
                ldif_entry = compare_changes(path, entry, change)
              else
                raise Exception.new("#{name}: Invalid changelog type")
              end

            end
            save_changelog_entry(type, path, entry, ldif_entry, &blk)
          end
        else
          log.warn "#{name}: Skip this entry, it should have a path, #{entry.inspect}"
        end
      end
    end

    def save_changelog_entry(type, path, entry, ldif_entry = '')
      with_ldap do |ldap|
        if type
          change_number = @last_change_number + 1
          changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, RUBYSYNC_SOURCE_INFO_ATTRIBUTE => path.to_s,
            'changenumber' => change_number.to_s, 'objectclass' => RUBYSYNC_CHANGELOG_CLASS,
            RUBYSYNC_CONTEXT_ATTRIBUTE => self.association_context, 'changetype' => type}

          if type.to_sym == :add
            entry.to_ldif {|line| ldif_entry = ldif_entry + line + "\n"} # TODO Not Ruby 1.9.+ compliant
            changelog_attributes['changes'] = [ldif_entry]
          elsif type.to_sym == :modify and !ldif_entry.empty?
            changelog_attributes['changes'] = [ldif_entry]
            dump_entry = ''
            entry.to_ldif {|line| dump_entry = dump_entry + line + "\n"} # TODO Not Ruby 1.9.+ compliant
            changelog_attributes[RUBYSYNC_DUMP_ENTRY_ATTRIBUTE] = [dump_entry]
          else
            return # Wrong type or ldif_entry is empty
          end


          begin
              changelog_dn_attribute = changelog_attributes.delete('dn').to_s
              result = ldap.add :dn => changelog_dn_attribute, :attributes => changelog_attributes

              if ldap.get_operation_result.code == 0
                # Changelog entry successfully added
                log.debug("#{name}: ldap.add returned '#{result}'")
                @last_change_number = change_number
                update_last_sync_state
                cle = ldap.search(:base => changelog_dn, :filter => Net::LDAP::Filter.eq(:changenumber, change_number.to_s)).first

                yield event_for_changelog_entry(cle)
              else
                log.debug changelog_attributes.inspect
                log.debug ldap.get_operation_result.message
                raise Exception.new("#{name}: Exception occurred while adding LDAP changelog entry n°#{change_number.to_s}")
              end

          rescue Exception => e
            log.debug e.inspect
            raise Exception.new("#{name}: Exception occurred while adding LDAP changelog entry n°#{change_number.to_s}")
          end
        else
          raise Exception.new("#{name}: Require a changelog type")
        end
      end
    end

    def delete_changelog_entries(&blk)
      with_ldap do |ldap|
        # TODO Filtering by @last_change_number boost performance. But in downside it's drop some entries who have been deleted
        # TODO Scan changelog to find deleted entries in background or periodicaly only ?
#        filter = "(& (!(changeType=delete)) (objectClass=#{RUBYSYNC_CHANGELOG_CLASS}) )"# (changeNumber>=#{@last_change_number.to_i})
        filter =  Net::LDAP::Filter.eq(:objectclass, RUBYSYNC_CHANGELOG_CLASS) & Net::LDAP::Filter.ne(:changetype, 'delete') # Net::LDAP DSL version
        ldap_changelogs_queue = {}

        ldap.search(:base => changelog_dn, :filter => filter) do |change|
          target_dn = change.send(RUBYSYNC_SOURCE_INFO_ATTRIBUTE)[0]

          filter_last_change = Net::LDAP::Filter.eq(RUBYSYNC_SOURCE_INFO_ATTRIBUTE, target_dn) & Net::LDAP::Filter.ge(:changenumber, change.changenumber[0])
          ldap_results = [change] if (ldap_results=ldap.search(:base => changelog_dn, :filter => filter_last_change)).empty?
          ldap_result = ldap_results.sort_by { |ldap_result| ldap_result[:changenumber][0].to_i }.last
          if ldap_result.changetype[0].to_sym != :delete # Changelogs of current dn wouldn't have a delete changetype

            if !self[target_dn] && !ldap_changelogs_queue.key?(target_dn)
             @last_change_number += 1
              new_changelogs_queue = delete_changelog_entry(target_dn, ldap_result, ldap_changelogs_queue, &blk)
              if new_changelogs_queue.respond_to?(:length) && new_changelogs_queue.length >= ldap_changelogs_queue.length
                ldap_changelogs_queue = new_changelogs_queue
              else
                log.warn "#{name}: Deleting unfound entry with path_field = #{target_dn}"

                changelog_attributes = {'dn' => 'changenumber=' + @last_change_number.to_s + ',' + changelog_dn,
                  RUBYSYNC_SOURCE_INFO_ATTRIBUTE => target_dn, 'changenumber' => @last_change_number.to_s,
                  'objectclass' => RUBYSYNC_CHANGELOG_CLASS, 'changetype' => 'delete',
                  RUBYSYNC_CONTEXT_ATTRIBUTE => self.association_context }
                changelog_dn_attribute = changelog_attributes.delete('dn').to_s
                ldap_changelogs_queue[target_dn] = { :dn => changelog_dn_attribute, :attributes => changelog_attributes }
                yield RubySync::Event.delete(self, target_dn)
              end
            end
          end
        end

        ldap_changelogs_queue.each do |target, operation|
          ldap.add(operation)
        end

        update_last_sync_state
      end
    end

    # Hook if you want to override the delete_changelog_entry behaviour
    # This method must return ldap_changelogs_queue's Hash or false
    def delete_changelog_entry(target, change, ldap_changelogs_queue)
      false
    end

  end

  class LdapChangelogRubyConnector < LdapChangelogConnector
    include LdapChangelogRubyChange
    
    changelog_dn 'ou=changelog,dc=example,dc=com'#"cn=changelog,ou=system"
    
    def initialize options={}
      super(options)
      restore_last_sync_state
    end

    #  def update_mirror path
    #    with_ldap do |ldap|
    #      filter = "(#{RUBYSYNC_SOURCE_INFO_ATTRIBUTE}>=#{path})"
    #      ldap.search(:base => changelog_dn, :filter =>filter, :return_result => false) ? type='add' : type='modify';
    #      change_number += 1 if (change_number=@last_change_number)
    #      changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, RUBYSYNC_SOURCE_INFO_ATTRIBUTE => path.to_s, 'changenumber' => change_number.to_s, 'objectclass' => RUBYSYNC_CHANGELOG_CLASS, 'changetype'=>type}
    #      ldap.add :dn=>changelog_attributes['dn'].to_s, :attributes=>changelog_attributes
    #    end
    #  end
    #
    #  def delete_from_mirror path
    ##    if @last_change_number > 0
    #      with_ldap do |ldap|
    #        change_number += 1 if (change_number=@last_change_number)
    #        changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, RUBYSYNC_SOURCE_INFO_ATTRIBUTE' => path.to_s, 'changenumber' => change_number.to_s, 'objectclass' => RUBYSYNC_CHANGELOG_CLASS, 'changetype'=>'delete'}
    #        ldap.add :dn=>changelog_attributes['dn'].to_s, :attributes=>changelog_attributes
    #      end
    ##    end
    #  end

  end
end
