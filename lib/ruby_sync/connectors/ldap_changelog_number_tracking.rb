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

#$VERBOSE = false
#require 'net/ldap'
#$VERBOSE = true


RUBYSYNC_CONNECTOR_STATE_CLASS = "rubySyncConnectorState"
RUBYSYNC_LAST_SYNC_ATTRIBUTE = 'rubySyncLastSync'

module RubySync::Connectors
  module LdapChangelogNumberTracking
    
    def restore_last_sync_state
      with_ldap do |ldap|
        filter = Net::LDAP::Filter.eq(RUBYSYNC_LAST_SYNC_ATTRIBUTE, "#{self.association_context.ldap_encode},*")
        if (ldap_result = ldap.search(:base => search_base, :filter => filter, :scope => Net::LDAP::SearchScope_BaseObject)).empty?
          @full_refresh_required = true
          @last_change_number = 0
          ldap.add_attribute(search_base, RUBYSYNC_LAST_SYNC_ATTRIBUTE,
            @last_sync="#{self.association_context.ldap_encode},#{@last_change_number.to_s},#{Time.now.strftime("%Y%m%d%H%M%S%z")}")
        else
          @full_refresh_required = false
          ldap_result[0][RUBYSYNC_LAST_SYNC_ATTRIBUTE].each do |last_sync|
            unless last_sync.match(/^#{self.association_context.ldap_encode},.*$/).nil?
              @last_sync = last_sync
              #Extract change_number from RUBYSYNC_LAST_SYNC_ATTRIBUTE value
                @last_change_number = @last_sync.split(",")[1].to_i
             break
            end
          end
        end
      end
    end

   def update_last_sync_state
      with_ldap do |ldap|
        if(@last_sync != (last_sync = "#{self.association_context.ldap_encode},#{@last_change_number.to_s},#{Time.now.strftime("%Y%m%d%H%M%S%z")}"))
          @full_refresh_required = false
          ldap.update_attribute(search_base, RUBYSYNC_LAST_SYNC_ATTRIBUTE.downcase.to_sym, @last_sync, @last_sync=last_sync)
        end
      end
    end
    
  end
end