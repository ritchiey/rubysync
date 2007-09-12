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


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'ldap_connector'
$VERBOSE = false
require 'net/ldap'
$VERBOSE = true


RUBYSYNC_ASSOCIATION_ATTRIBUTE = "RubySyncAssociation"
RUBYSYNC_ASSOCIATION_CLASS = "RubySyncSynchable"


module LdapAssociations
  

    def associate association, path
      with_ldap do |ldap|
        # todo: check and warn if path is outside of search_base
        ldap.modify :dn=>path, :operations=>[
          [:add, RUBYSYNC_ASSOCIATION_ATTRIBUTE, association.to_s]
          ]
      end
    end
    
    def path_for_association association
      with_ldap do |ldap|
        filter = "#{RUBYSYNC_ASSOCIATION_ATTRIBUTE}=#{association.to_s}"
        log.debug "Searching with filter: #{filter}"
        results = ldap.search :base=>@search_base,
                    :filter=>filter,
                    :attributes=>[]
        results or return nil
        case results.length
        when 0: return nil
        when 1: return results[0].dn
        else
          raise Exception.new("Duplicate association found for #{association.to_s}")
        end
      end
    end
    
    def associations_for path
      with_ldap do |ldap|
        results = ldap.search :base=>path,
                    :scope=>Net::LDAP::SearchScope_BaseObject,
                    :attributes=>[RUBYSYNC_ASSOCIATION_ATTRIBUTE]
        unless results and results.length > 0
          log.warn "Attempted association lookup on non-existent LDAP entry '#{path}'"
          return []
        end
        associations = results[0][RUBYSYNC_ASSOCIATION_ATTRIBUTE]
        return (associations)? associations.as_array : []
      end
    end
    
    def remove_association association
      path = path_for_association association
      with_ldap do |ldap|
        ldap.modify :dn=>path, :modifications=>[
          [:delete, RUBYSYNC_ASSOCIATION_ATTRIBUTE, association.to_s]
          ]
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
        result = ldap.search :base=>search_base, :filter=>"#{association_attribute}=#{key}"
        return nil if !result or result.size == 0
        result[0]
      end
    end    

end


