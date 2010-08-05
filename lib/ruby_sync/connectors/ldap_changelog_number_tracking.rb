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

    attr_accessor :sync_info, :last_change_number

    def restore_last_sync_state
      with_ldap do |ldap|
        filter = Net::LDAP::Filter.eq(RUBYSYNC_LAST_SYNC_ATTRIBUTE, "#{association_context},*")
        if (ldap_result = ldap.search(:base => path_cookie, :filter => filter, :scope => Net::LDAP::SearchScope_BaseObject)).empty?
          @full_refresh_required = true
          @last_change_number = 0
          sync_info = @sync_info ? @sync_info : Time.now.strftime("%Y%m%d%H%M%S%z")
          ldap.add_attribute(path_cookie, RUBYSYNC_LAST_SYNC_ATTRIBUTE,
            @last_sync="#{self.association_context},#{@last_change_number.to_s},#{sync_info}")
        else
          @full_refresh_required = false
          ldap_result[0][RUBYSYNC_LAST_SYNC_ATTRIBUTE.downcase].each do |last_sync|
            if last_sync.match(/^#{Regexp.escape(association_context)},.+$/)
              @last_sync = last_sync
              #Extract change_number from RUBYSYNC_LAST_SYNC_ATTRIBUTE value
              @last_change_number = @last_sync.split(",")[1].to_i
              break
            end
          end
   
          log.warn 'Unable to restore the last synchronization state' unless @last_change_number
        end
      end
    end

    def update_last_sync_state
      with_ldap do |ldap|
        sync_info = @sync_info ? @sync_info : Time.now.strftime("%Y%m%d%H%M%S%z")
        if(@last_sync != (last_sync = "#{self.association_context},#{@last_change_number.to_s},#{sync_info}"))
          @full_refresh_required = false
          ldap.update_attribute(path_cookie, RUBYSYNC_LAST_SYNC_ATTRIBUTE, @last_sync, @last_sync=last_sync)
        end
      end
    end

    def extract_last_sync_info
      if @last_change_number && @last_change_number > 0 && @last_sync
        sync_info = @last_sync.match(/^#{Regexp.escape(association_context)},[0-9]+,(.+)$/)
        if sync_info && sync_info[1]
          sync_info = (@sync_info)? sync_info[1] : Time.parse(sync_info[1])
          return sync_info
        end
        log.warn 'Unable to extract information of the last synchronization'
        return nil
      else
        log.debug "First synchronization, so there isn't last synchronization data"
        return nil
      end
    end
    
  end
end