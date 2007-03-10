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



module RubySync
  module Connectors
    
    # This is included into BaseConnector. The methods here are not handle processing events
    # and are not likely to be overridden so they've been taken out of BaseConnector for
    # readibility.
    module ConnectorEventProcessing
    
      def process(event)
        case event.type
        when :add: return perform_add(event)
        when :delete: return perform_delete(event)
        when :modify: return perform_modify(event)
        else
            raise Exception.new("#{name}: Unknown event type '#{event.type}' received")
        end
      end

      def perform_add event
        log.info "Adding '#{event.target_path}' to '#{name}'"
        raise Exception.new("#{name}: Entry with path '#{event.target_path}' already exists, add failing.") if self[event.target_path]
        if is_vault? && event.association_key != nil && path_for_association_key(event.association_key)
          raise Exception.new("#{name}: Association_key already in use. Add failing.") 
        end
        call_if_exists(:target_transform, event)
        add event.target_path, event.payload
        return association_key_for(event.target_path) unless is_vault?
        if is_vault? && !event.association_key
          raise Exception.new("#{name}: No association key supplied to add.")
        else
          associate_with_foreign_key(event.association_key, event.target_path)
        end
      end

      def perform_delete event
        raise Exception.new("#{name}: Delete of unassociated object. No action taken.") unless event.association_key
        path = path_for_association_key(event.association_key)
        log.info "Deleting '#{path}' from '#{name}'"
        raise Exception.new("#{name}: Attempted to delete non-existent entry '#{path}'") unless delete(path)
        return nil # don't want to create any new associations
      end

      def perform_modify event
        path = path_for_association_key(event.association_key)
        raise Exception.new("#{name}: Attempted to modify non-existent entry '#{path}'") unless self[path]
        call_if_exists(:target_transform, event)
        modify path, event.payload
        return (is_vault?)? nil : association_key_for(event.target_path)
      end
    end
  end
end
