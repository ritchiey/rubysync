#!/usr/bin/env ruby -w
#
#  Copyright (c) 2009 Nowhere Man. All rights reserved.
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


lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'digest/md5'

module RubySync::Connectors::ActiveRecordChangeTracking

  # Disable mirror updates for incoming events
  def update_mirror(path); end
  def delete_from_mirror(path); end

  def each_change
    # Process each RubySyncEvent and then delete it from the db.
    if Object.const_defined?(:RubySyncEvent) and @models.include?('RubySyncEvent')
      ::RubySyncEvent.find(:all).each do |rse|
        event = RubySync::Event.new(rse.event_type, self, rse.trackable_id, nil, to_payload(rse))
        yield event

        #usefull ?
        if is_vault? and @pipeline and rse.event_type==:delete
          association = association_for @pipeline.association_context, rse.trackable_id
          remove_association association
        end

        ::RubySyncEvent.delete rse
      end
    else
      # scan existing entries to see if any new or modified
      each_entry.each do |entry|
        digest = digest(entry)
        unless stored_digest = track_class.find_by_key(entry.id) and digest == stored_digest
          operations = create_operations_for(entry_from_active_record(entry))
          yield RubySync::Event.add(self, entry.id, nil, operations)
          track_class.create(:key => entry.id, :digest => digest)
        end
      end

      # scan track to find deleted
      track_class.find(:all).each do |record|
        key=record.key
        unless self[key]
          yield RubySync::Event.delete(self, key)
          track_class.destroy_all(:key => key)
          if is_vault? and @pipeline
            association = association_for @pipeline.association_context, key
            remove_association association
          end
        end
      end
    end
    

  end

  def digest(o)
    Digest::MD5.hexdigest(entry_from_active_record(o).to_yaml)
  end

  # Create a hash suitable to use as rubysync event payload
  def to_payload ar_event
    ar_event.operations.map do |op|
      RubySync::Operation.new(op.operation.to_sym, op.field_name, op.values.map {|v| v.value})
    end
  end

end