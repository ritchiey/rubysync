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


require 'digest/md5'

# When included by a connector, tracks changes to the connector using
# a dbm database of the form path:digest. Digest is a MD5 hash of the
# record so we can tell if the record has changed. We can't, however,
# tell how the record has changed so change events generated will be
# for the entire record.
module RubySync::Connectors::MemoryChangeTracking


  def shadow
    @shadow ||= {}
  end

  # Subclasses MAY override this to interface with the external system
  # and generate an event for every change that affects items within
  # the scope of this connector.
  #
  # The default behaviour is to compare a hash of each entry in the
  # database with a stored hash of its previous value and generate
  # add, modify and delete events appropriately. This is normally a very
  # inefficient way to operate so overriding this method is highly
  # recommended if you can detect changes in a more efficient manner.
  #
  # This method will be called repeatedly until the connector is
  # stopped.
  def each_change
    # scan existing entries to see if any new or modified
    each_entry do |path, entry|
      digest = digest(entry)
      unless stored_digest = shadow[path.to_s] and digest == stored_digest
        operations = create_operations_for(entry)
        yield RubySync::Event.add(self, path, nil, operations)
        shadow[path.to_s] = digest
      end
    end
          
    # scan shadow to find deleted
    shadow.each do |key, stored_hash|
      unless self[key]
        yield RubySync::Event.delete(self, key)
        shadow.delete key
        if is_vault? and @pipeline
          association = association_for @pipeline.association_context, key
          remove_association association
        end
      end
    end
  end
      
  def digest(o)
    Digest::MD5.hexdigest(o.to_yaml)
  end

  def remove_mirror
    @shadow = nil
  end
      
  def delete_from_mirror path
    shadow.delete(path.to_s)
  end

  def update_mirror path
    entry = self[path.to_s]
    shadow[path.to_s] = digest(entry)
  end
      
end 
