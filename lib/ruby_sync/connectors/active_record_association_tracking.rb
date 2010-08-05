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


lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'

module RubySync::Connectors::ActiveRecordAssociationTracking
  
  def associate association, path
    log.debug "Associating '#{association}' with '#{path}'"
    ruby_sync_association.create :synchronizable_id => path, :synchronizable_type => ar_class.name,
      :context => association.context, :key => association.key.to_s
  end
  
  def find_associated association
    ruby_sync_association.find_by_context_and_key association.context, association.key.to_s
  end
  
  def path_for_association association
    assoc = ruby_sync_association.find_by_context_and_key association.context, association.key.to_s
    (assoc)? assoc.synchronizable_id : nil
  end
  
  def association_key_for context, path
    record = ruby_sync_association.find_by_synchronizable_id_and_synchronizable_type_and_context path, ar_class.name, context
    record and record.key
  end
  
  def associations_for(path)
    ruby_sync_association.find_by_synchronizable_id_and_synchronizable_type(path, ar_class.name)
  rescue ActiveRecord::RecordNotFound
    return nil
  end
  
  def remove_association association
    ruby_sync_association.find_by_context_and_key(association.context, association.key.to_s).destroy
  rescue ActiveRecord::RecordNotFound
    return nil
  end

  private

  def ruby_sync_association
    unless @ruby_sync_association
      if Object.const_defined?('RubySyncAssociation') and @models.include?('RubySyncAssociation')
        @ruby_sync_association = ::RubySyncAssociation
        @ruby_sync_association.establish_connection(db_config)
      elsif track.respond_to? :associations_model
        @ruby_sync_association = track.associations_model.to_s.camelize.constantize
        @ruby_sync_association.establish_connection(track.db_config)
      end
    end
    @ruby_sync_association
  end

end