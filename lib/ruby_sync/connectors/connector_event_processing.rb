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



module RubySync
  module Connectors
    
    # This is included into BaseConnector.
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

      # Add a record to the connected store. If acting as vault, also associate with the attached association
      # key for later retrieval. This implementation assumes that the target path is used. Connectors that
      # make up their own key on creation of a record will need to override this.
      def perform_add event
        log.info "Adding '#{event.target_path}' to '#{name}'"
        raise Exception.new("#{name}: Entry with path '#{event.target_path}' already exists, add failing.") if self[event.target_path]
        if is_vault? && event.association && path_for_association(event.association)
          raise Exception.new("#{name}: Association already in use. Add failing.") 
        end
        call_if_exists(:target_transform, event)
        if add(event.target_path, event.payload)
          log.info "Add succeeded"
          if is_vault?
            if event.association
              associate(event.association, event.target_path)
            else
              raise Exception.new("#{name}: No association key supplied to add.")
            end
          else
            return own_association_key_for(event.target_path) 
          end
        else
          log.warn "Failed to add '#{event.target_path}' to '#{name}'"
          return false
        end
      end

      def perform_delete event
        raise Exception.new("#{name}: Delete of unassociated object. No action taken.") unless event.association
        path = (is_vault?)? path_for_association(event.association) : path_for_own_association_key(event.association.key)
        log.info "Deleting '#{path}' from '#{name}'"
        delete(path) or log.warn("#{name}: Attempted to delete non-existent entry '#{path}'\nMay be an echo of a delete from this connector, ignoring.")
        return nil # don't want to create any new associations
      end

      def perform_modify event
        path = (is_vault?)? path_for_association(event.association) : path_for_own_association_key(event.association.key)
        raise Exception.new("#{name}: Attempted to modify non-existent entry '#{path}'") unless self[path]
        call_if_exists(:target_transform, event)
        modify path, event.payload
        return (is_vault?)? nil : own_association_key_for(event.target_path)
      end
    end
  end
end
