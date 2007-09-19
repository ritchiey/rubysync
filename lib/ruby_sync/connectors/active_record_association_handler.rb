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

require 'rubysync'

module RubySync::Connectors::ActiveRecordAssociationHandler
  
  def associate association, path
    log.debug "Associating '#{association}' with '#{path}'"
    ruby_sync_association.create :synchronizable_id=>path, :synchronizable_type=>ar_class.name,
                                 :context=>association.context, :key=>association.key
  end
  
  def find_associated association
    ruby_sync_association.find_by_context_and_key association.context, association.key
  end
  
  def path_for_association association
    assoc = ruby_sync_association.find_by_context_and_key association.context, association.key
    (assoc)? assoc.synchronizable_id : nil
  end
  
  def association_key_for context, path
    record = ruby_sync_association.find_by_synchronizable_id_and_synchronizable_type_and_context path, model.to_s, context
    record and record.key
  end
  
  def associations_for(path)
    ruby_sync_association.find_by_synchronizable_id_and_synchronizable_type(path, model.to_s)
  rescue ActiveRecord::RecordNotFound
    return nil
  end
  
  def remove_association association
     ruby_sync_association.find_by_context_and_key(association.context, association.key).destroy
  rescue ActiveRecord::RecordNotFound
     return nil
  end
  
private

  def ruby_sync_association
    unless @ruby_sync_association
      @ruby_sync_association = ::RubySyncAssociation
      ::RubySyncAssociation.establish_connection(db_config)
    end
    @ruby_sync_association
  end

end