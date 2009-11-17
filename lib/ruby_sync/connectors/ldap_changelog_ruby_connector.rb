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
require 'net/ldif'
$VERBOSE = false
require 'net/ldap'
#$VERBOSE = true

RUBYSYNC_CHANGELOG_CLASS = "rubySyncChangeLogEntry"
RUBYSYNC_DUMP_ENTRY_ATTRIBUTE = "rubySyncDumpEntry"
RUBYSYNC_CONTEXT_ATTRIBUTE = "rubySyncContext"

module RubySync::Connectors

  class LdapChangelogRubyConnector < LdapChangelogConnector

    option             :changelog_dn
    changelog_dn       'ou=changelog,dc=example,dc=com'#"cn=changelog,ou=system"

    def initialize options={}
      super(options)
      restore_last_sync_state
    end

    def each_change(&blk)
      #      unless @last_sync == nil and @last_sync.split(",")[0] == self.association_context.ldap_encode
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
            log.info("change_number > @last_change_number")
            # TODO: A proper DN object would be nice instead of string manipulation
            target_dn = change.targetdn[0].gsub(/\s*,\s*/,',')
            if target_dn =~ /#{search_base}$/oi
              change_type = change.changetype[0]
              #              if change_type.to_sym == :delete
              #                 event = RubySync::Event.delete(self, target_dn)
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

      # scan changelog entries to find deleted
      delete_changelog_entries(&blk)
   
    end

    #dummy method, because we don't have to skip changelog entries with software LDAP changelog
    def skip_existing_changelog_entries    
    end

    #Compare current entry with last entry store in changeLogEntry and return a ldif_entry
    def compare_changes(path, entry, change)
      ldif_entry = ''
      if change.attribute_names.include? :changes or change.attribute_names.include? RUBYSYNC_DUMP_ENTRY_ATTRIBUTE.downcase.to_sym

        # using RUBYSYNC_DUMP_ENTRY_ATTRIBUTE only for change_type :modify
        change.changetype[0].to_sym == :add ? changes_attribute = 'changes' : changes_attribute = RUBYSYNC_DUMP_ENTRY_ATTRIBUTE.downcase.to_sym

        last_entry = Net::LDIF.parse("dn: #{path}\nchangetype: add\n#{change.send(changes_attribute)[0]}")[0].data
        raise Exception.new("Wrong type for last_entry and/or entry") unless last_entry.respond_to?(:deep_diff) and entry.respond_to?(:deep_diff)

        #TODO Moving this stuff into an Module, named HashComparator with methods like those of Helpers section in #TcHashComparator, because it'll be useful for other connectors or pipelines? (eg: #BaseConnector, #BasePipeline)
          old_attributes = last_entry.symbolize_keys.deep_diff(entry.symbolize_keys)
          old_attributes.delete(:dn)# attribute dn is useless

          new_attributes = entry.symbolize_keys.deep_diff(last_entry.symbolize_keys)#new or modified
          new_attributes.delete(:dn)# attribute dn is useless

          replace_attributes = new_attributes.keys & old_attributes.keys# to replace
          delete_attributes = old_attributes.keys - replace_attributes# to remove
          add_attributes = new_attributes.keys - replace_attributes# to create
       
        #Deleting or replacing attributes only if the lastest change has been done by the actual client/vault
        if change.send(RUBYSYNC_CONTEXT_ATTRIBUTE)[0]==self.association_context.ldap_encode
                 
          delete_attributes.each do |key|
            old_attributes[key].each do |value|
              ldif_entry = ldif_entry + "delete: #{key}\n#{key}: #{value}\n-\n"
              log.debug("remove attribute #{key}: #{value}")
            end
          end

          replace_attributes.each do |key|
            if entry.symbolize_keys[key].is_a?(Array) or last_entry.symbolize_keys[key].is_a?(Array)
              old_attributes[key].each do |value|
                ldif_entry = ldif_entry + "delete: #{key}\n#{key}: #{value}\n-\n"
                log.debug("in replace : remove attribute #{key}: #{value}")
              end
              new_attributes[key].each do |value|
                ldif_entry = ldif_entry + "add: #{key}\n#{key}: #{value}\n-\n"
                log.debug("in replace : add attribute #{key}: #{value}")
              end
            else
              value = new_attributes[key]
              ldif_entry = ldif_entry + "replace: #{key}\n#{key}: #{value}\n-\n"
              log.debug("replace attribute #{key}: #{value}")
            end
          end
        end

        add_attributes.each do |key|
          new_attributes[key].each do |value|
            ldif_entry = ldif_entry + "add: #{key}\n#{key}: #{value}\n-\n"
            log.debug("add attribute #{key}: #{value}")
          end
        end
        
        log.debug("ldif changelog entry is empty") if ldif_entry.empty?
        ldif_entry
      else
        raise Exception.new("Invalid changelog entry, 'changes' or '#{RUBYSYNC_DUMP_ENTRY_ATTRIBUTE}' attributes are empty")#No changes found
      end
      
    end
    
    def save_changelog_entries(&blk)
      each_entry do |path, entry|
  #          operations = operations_for_entry(entry)
        #          yield RubySync::Event.add(self, entry['dn'].to_s, nil, operations)
        #          perform_operations(operations

        if path != search_base
          with_ldap do |ldap|
            ldif_entry = ''

            filter = Net::LDAP::Filter.eq("targetdn", path) & Net::LDAP::Filter.eq("objectclass", "changeLogEntry")
            #filter = filter & Net::LDAP::Filter.ge("changenumber", @last_change_number.to_i.to_s) unless @full_refresh_required
            if !(ldap_result=ldap.search(:base => changelog_dn, :filter => filter)) || ldap_result.empty?
              type='add'# Create entry
            else
              #changes = ldap_result
              #changes.each do |change|
              change = ldap_result.last
  #            if change.changenumber[0].to_i < @last_change_number.to_i
                case change.changetype[0].to_sym
                when :delete
                  type='add'# Recreate entry
                when :add, :modify
                  type = 'modify'# Update existing entry
                  ldif_entry = compare_changes(path, entry,change)
                else
                  raise Exception.new("Invalid changelog type")
                end
  #            else
  #              log.debug("@last_change_number is lesser than current change number")
  #            end
              #end
            end
            save_changelog_entry(type, path, entry, ldif_entry, &blk)
          end
        else
          log.debug "Skip this entry, it should have a path"
        end
      end
    end

    def save_changelog_entry(type, path, entry, ldif_entry = '')
      with_ldap do |ldap|
        if type
          change_number = @last_change_number + 1
          changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, 'targetdn' => path.to_s,
            'changenumber' => change_number.to_s,'objectclass'=>['changeLogEntry', RUBYSYNC_CHANGELOG_CLASS],
            RUBYSYNC_CONTEXT_ATTRIBUTE => self.association_context.ldap_encode, 'changetype'=>type}

          if type.to_sym==:add
            entry.to_ldif {|line| ldif_entry = ldif_entry + line + "\n"}#TODO Not Ruby 1.9.+ compliant
            changelog_attributes['changes'] = [ldif_entry]
          elsif type.to_sym==:modify and !ldif_entry.empty?

            changelog_attributes['changes'] = [ldif_entry]
            dump_entry = ''
            entry.to_ldif {|line| dump_entry = dump_entry + line + "\n"}#TODO Not Ruby 1.9.+ compliant
            changelog_attributes[RUBYSYNC_DUMP_ENTRY_ATTRIBUTE] = [dump_entry]
          else            
            return#Wrong type or ldif_entry is empty
          end


          begin           
              #Changelog entry successfully added
              changelog_dn_attribute = changelog_attributes.delete('dn').to_s
              result = ldap.add :dn=>changelog_dn_attribute, :attributes=>changelog_attributes
              log.debug("ldap.add returned '#{result}'")
              @last_change_number=change_number
              update_last_sync_state
              cle = ldap.search(:base => changelog_dn, :filter => "changenumber=#{change_number.to_s}").first

              yield event_for_changelog_entry(cle)
            
          rescue
            raise Exception.new("Exception occurred while adding LDAP changelog entry n°#{change_number.to_s}")
          end
        else
          raise Exception.new("Require a changelog type")
        end
      end
    end

    def delete_changelog_entries
      with_ldap do |ldap|
        # TODO Filtering by @last_change_number boost performance. But in downside it's drop some entries who have been deleted
        # TODO Scan changelog to find deleted entries in background or periodicaly only ?
        filter = "(& (!(changeType=delete)) (objectClass=changeLogEntry) )"# (changeNumber>=#{@last_change_number.to_i})
        ldap.search(:base => changelog_dn, :filter => filter) do |change|
          target_dn = change.targetdn[0]

          filter_last_change = Net::LDAP::Filter.eq( "targetdn", target_dn) & Net::LDAP::Filter.ge('changeNumber',"#{change.changenumber[0].to_i}")
          ldap_result = [change] if (ldap_result=ldap.search(:base => changelog_dn, :filter => filter_last_change)).empty?

          unless ldap_result.last.changetype[0].to_sym == :delete# Changelogs of current dn wouldn't have a delete changetype
            filter_attribute = target_dn.scan(/^\s*(\w+)\s*=\s*(\w+).*$/)[0]
            filter_dn = Net::LDAP::Filter.eq(filter_attribute[0], filter_attribute[1])
            if ldap.search(:base => search_base, :filter => filter_dn).empty?
              yield RubySync::Event.delete(self, target_dn)

              change_number = @last_change_number +=1
              changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, 'targetdn' => target_dn, 'changenumber' => change_number.to_s,'objectclass'=>'changeLogEntry' , 'changetype'=>'delete'}
              changelog_dn_attribute = changelog_attributes.delete('dn').to_s
              ldap.add :dn=>changelog_dn_attribute, :attributes=>changelog_attributes
              update_last_sync_state
            end
          end
        end
      end
    end

    #  def update_mirror path
    #    with_ldap do |ldap|
    #      filter = "(targetdn>=#{path})"
    #      ldap.search(:base => changelog_dn, :filter =>filter, :return_result => false) ? type='add' : type='modify';
    #      change_number += 1 if (change_number=@last_change_number)
    #      changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, 'targetdn' => path.to_s, 'changenumber' => change_number.to_s,'objectclass'=>'changeLogEntry' , 'changetype'=>type}
    #      ldap.add :dn=>changelog_attributes['dn'].to_s, :attributes=>changelog_attributes
    #    end
    #  end
    #
    #  def delete_from_mirror path
    ##    if @last_change_number > 0
    #      with_ldap do |ldap|
    #        change_number += 1 if (change_number=@last_change_number)
    #        changelog_attributes = {'dn' => 'changenumber=' + change_number.to_s + ',' + changelog_dn, 'targetdn' => path.to_s, 'changenumber' => change_number.to_s,'objectclass'=>'changeLogEntry' , 'changetype'=>'delete'}
    #        ldap.add :dn=>changelog_attributes['dn'].to_s, :attributes=>changelog_attributes
    #      end
    ##    end
    #  end

  end
end