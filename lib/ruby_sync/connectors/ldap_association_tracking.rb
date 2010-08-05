#!/usr/bin/env ruby
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
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


RUBYSYNC_ASSOCIATION_CLASS = "rubySyncSynchable"
RUBYSYNC_ASSOCIATION_ATTRIBUTE = "rubySyncAssociation"

module RubySync::Connectors
  module LdapAssociationTracking

    attr_accessor :last_change_number

    def associate association, path
      # TODO: check and warn if path is outside of search_base

      if path && (entry = self[path])
        if ( !entry[RUBYSYNC_ASSOCIATION_ATTRIBUTE.downcase] ||
            !entry[RUBYSYNC_ASSOCIATION_ATTRIBUTE.downcase][0].include?(association.to_s) )
          with_ldap do |ldap|
            object_classes = entry['objectclass']
            if object_classes && !object_classes.include?(RUBYSYNC_ASSOCIATION_CLASS.downcase)
               ldap.replace_attribute path, :objectclass,
                 object_classes << RUBYSYNC_ASSOCIATION_CLASS
            end
            ldap.add_attribute path, RUBYSYNC_ASSOCIATION_ATTRIBUTE, association.to_s
          end
        end
      end
    end
    
    def path_for_association association
      with_ldap do |ldap|
        filter = Net::LDAP::Filter.eq(RUBYSYNC_ASSOCIATION_ATTRIBUTE,
          association.to_s)
        log.debug "Searching with filter: #{filter}"
   
        results = ldap.search :base => search_base, :filter => filter
        results or return nil
        case results.length
        when 0 then return nil
        when 1 then return results[0].dn
        else
          raise Exception.new("Duplicate association found for #{association.to_s}")
        end
      end
    end
    
    def associations_for path
      with_ldap do |ldap|
        results = ldap.search :base => path, :scope => Net::LDAP::SearchScope_BaseObject,
          :attributes => [RUBYSYNC_ASSOCIATION_ATTRIBUTE]
        unless results and results.length > 0
          log.warn "Attempted association lookup on non-existent LDAP entry '#{path}'"
          return []
        end
        associations = results[0][RUBYSYNC_ASSOCIATION_ATTRIBUTE.downcase].to_s
        return (associations)? as_array(associations) : []
      end
    end
    
    def remove_association association
      path = path_for_association association
      with_ldap do |ldap|
        ldap.replace_attribute path, RUBYSYNC_ASSOCIATION_ATTRIBUTE, association.to_s
      end
    end

    def association_key_for context, path
      with_ldap do |ldap|
        filter = Net::LDAP::Filter.eq(RUBYSYNC_ASSOCIATION_ATTRIBUTE,"#{(context+'$*')}")
        results = ldap.search :base => path,
          :scope => Net::LDAP::SearchScope_BaseObject,
          :attributes => [RUBYSYNC_ASSOCIATION_ATTRIBUTE],
          :filter => filter
        results or return nil
        case results.length
        when 0 then return nil
        when 1 then return results[0][RUBYSYNC_ASSOCIATION_ATTRIBUTE.downcase].to_s.match('^.*\$(.*)$')[1]
        else
          raise Exception.new("Duplicate association found for context '#{context.to_s}' and path '#{path.to_s}'")
        end
      end
    end


    # def associate_with_foreign_key key, path
    #   with_ldap do |ldap|
    #     ldap.add_attribute(path, association_attribute, key.to_s)
    #   end
    # end
    # 
    # def path_for_foreign_key key
    #   entry = entry_for_foreign_key key
    #   (entry)? entry.dn : nil
    # end
    # 
    # def foreign_key_for path
    #     entry = self[path]
    #     (entry)? entry.dn : nil # TODO: That doesn't look right. Should return an association key, not a path.
    # end
    # 
    # def remove_foreign_key key
    #   with_ldap do |ldap|
    #     entry = entry_for_foreign_key key
    #     if entry
    #       modify :dn=>entry.dn, :operations=>[ [:delete, association_attribute, key] ]
    #     end
    #   end
    # end
    # 
    # def find_associated foreign_key
    #   entry = entry_for_foreign_key key
    #   (entry)? operations_for_entry(entry) : nil
    # end  
    
    private
    
    def entry_for_foreign_key key
      with_ldap do |ldap|
        result = ldap.search :base => search_base, :filter => Net::LDAP::Filter.eq(association_attribute, key)
        return nil if !result or result.size == 0
        result[0]
      end
    end    

  end


end