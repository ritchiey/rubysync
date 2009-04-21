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


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'ruby_sync/connectors/ldap_connector'
require 'net/ldif'
$VERBOSE = false
require 'net/ldap'
#$VERBOSE = true

module RubySync::Connectors
  class LdapChangelogConnector < RubySync::Connectors::LdapConnector

    option             :changelog_dn
    changelog_dn          "cn=changelog"

    def initialize options={}
      super options
      @last_change_number = 1
      # TODO: Persist the current CSN, for now we'll just skip to the end of the changelog
      skip_existing_changelog_entries
    end
    # Look for changelog entries. This is not supported by all LDAP servers
    # Changelog entries have these attributes
    # targetdn
    # changenumber
    # objectclass
    # changes
    # changetime
    # changetype
    # dn
    #
    # TODO: Detect presence/location of changelog from root DSE
    def each_change
      with_ldap do |ldap|
        log.debug "@last_change_number = #{@last_change_number}"
        filter = "(changenumber>=#{@last_change_number})"
        first = true
        @full_refresh_required = false
        ldap.search :base => changelog_dn, :filter =>filter do |change|
          change_number = change.changenumber[0].to_i
          if first
            first = false
            # TODO: Persist the change_number so that we don't do a full resync everytime rubysync starts
            if change_number != @last_change_number
              log.warn "Earliest change number (#{change_number}) differs from that recorded (#{@last_change_number})."
              log.warn "A full refresh is required."
              @full_refresh_required = true
              break
            end
          else
            @last_change_number = change_number if change_number > @last_change_number
            # TODO: A proper DN object would be nice instead of string manipulation
            target_dn = change.targetdn[0].gsub(/\s*,\s*/,',')
            if target_dn =~ /#{search_base}$/oi
              change_type = change.changetype[0]
              event = event_for_changelog_entry(change)
              yield event
            end
          end
        end
      end
      each_entry if @full_refresh_required
    end


    def skip_existing_changelog_entries
      with_ldap do |ldap|
        filter = "(changenumber>=#{@last_change_number})"
        @full_refresh_required = false
        ldap.search :base => changelog_dn, :filter =>filter do |change|
          change_number = change.changenumber[0].to_i
          @last_change_number = change_number if change_number > @last_change_number
        end
      end
    end


    # Called by unit tests to inject data
    def test_add id, details
      details << RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson', 'organizationalPerson', 'person', 'top', 'RubySyncSynchable'])
      add id, details
    end


    private


    def event_for_changelog_entry cle
      payload = nil
      dn = cle.targetdn[0]
      changetype = cle.changetype[0]
      if cle.attribute_names.include? :changes
        payload = []
        cr = Net::LDIF.parse("dn: #{dn}\nchangetype: #{changetype}\n#{cle.changes[0]}")[0]
        if changetype.to_sym == :add
          # cr.data will be a hash of arrays or strings (attr-name=>[value1, value2, ...])
          cr.data.each do |name, values|
            payload << RubySync::Operation.add(name, values)
          end
        else
          # cr.data will be an array of arrays of form [:action, :subject, [values]]
          cr.data.each do |record|
            payload << RubySync::Operation.new(record[0], record[1], record[2])
          end
        end
      end
      RubySync::Event.new(changetype, self, dn, nil, payload)
    end

  end
end