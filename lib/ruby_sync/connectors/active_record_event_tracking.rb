#!/usr/bin/env ruby
#
#  Copyright (c) 2010 Nowhere Man
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

module RubySync::Connectors
  module ActiveRecordEventTracking

    attr_accessor :sync_info, :last_event_id

    def restore_last_sync_state
      if self.class.name != self.association_context
        if (last_sync_record = ::RubySyncState.first(:conditions => {:context => self.association_context}) ).blank?
          @full_refresh_required = true
          @last_event_id = 0
          sync_info = (!@sync_info.blank?)? @sync_info : Time.zone.now.strftime("%Y%m%d%H%M%S%z")
          ::RubySyncState.create(:info => sync_info, :context => self.association_context, :last_event_id => @last_event_id)
          self.last_sync = "#{self.association_context},#{@last_event_id.to_s},#{sync_info}"
        else
          @full_refresh_required = false
          self.last_sync = "#{last_sync_record.context},#{last_sync_record.last_event_id.to_s},#{last_sync_record.info}"
          @last_event_id = last_sync_record.last_event_id

          log.warn 'Unable to restore the last synchronization state' if @last_event_id.blank?
        end
      end
    end

    def update_last_sync_state
      if self.class.name != self.association_context
        sync_info = (!@sync_info.blank?)? @sync_info : Time.zone.now.strftime("%Y%m%d%H%M%S%z")
        if(@last_sync != (last_sync = "#{self.association_context},#{@last_event_id.to_s},#{sync_info}"))
          @full_refresh_required = false
          ar_last_sync = ::RubySyncState.first(:conditions =>
              { :info => @last_sync.split(",")[2], :context => @last_sync.split(",")[0], :last_event_id => @last_sync.split(",")[1].to_i } )
          ar_last_sync.update_attributes(:info => sync_info, :context => self.association_context, :last_event_id => @last_event_id)
          self.last_sync = last_sync
        end
      end
    end

    def extract_last_sync_info
      if self.class.name != self.association_context
        if @last_event_id && @last_event_id > 0 && @last_sync
          sync_info = @last_sync.match(/^#{Regexp.escape(self.association_context)},[0-9]+,(.+)$/)
          if sync_info && sync_info[1]
            sync_info = (!@sync_info.blank?)? sync_info[1] : Time.zone.parse(sync_info[1])

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
end
