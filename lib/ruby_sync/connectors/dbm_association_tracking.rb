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

require 'yaml'
require 'yaml/dbm'
 

module RubySync
  module Connectors
    module DbmAssociationTracking
        
            # Store association for the given path
      def associate association, path
        YAML::DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs = dbm[path.to_s] || {}
          assocs[association.context.to_s] = association.key.to_s
          dbm[path.to_s] = assocs
        end
        DBM.open(association_to_path_dbm_filename) do |dbm|
          dbm[association.to_s] = path
        end
      end
      
      def path_for_association association
        is_vault? or return path_for_own_association_key(association.key)
        DBM.open(association_to_path_dbm_filename) do |dbm|
          dbm[association.to_s]
        end
      end
      
      def associations_for path
        YAML::DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs =  dbm[path.to_s]
          assocs.values
        end
      end


      def remove_association association
        path = nil
        DBM.open(association_to_path_dbm_filename) do |dbm|
          return unless path =dbm.delete(association.to_s)
        end
        YAML::DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs = dbm[path.to_s]
          assocs.delete(association.context) and dbm[path.to_s] = assocs
        end
      end

      def association_key_for context, path
        YAML::DBM.open(path_to_association_dbm_filename) do |dbm|
          assocs = dbm[path.to_s] || {}
          assocs[context.to_s]
        end
      end

      def remove_associations
        File.delete_if_exists(["#{association_to_path_dbm_filename}.db","#{path_to_association_dbm_filename}.db"])
      end

      
            # Stores association keys indexed by path:association_context
        def path_to_association_dbm_filename
          dbm_path + "_path_to_assoc"
        end

      # Stores paths indexed by association_context:association_key
        def association_to_path_dbm_filename
          dbm_path + "_assoc_to_path"
        end


      
    end
  end
end
