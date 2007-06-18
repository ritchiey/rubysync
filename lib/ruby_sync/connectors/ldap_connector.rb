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
require 'net/ldif'
$VERBOSE = false
require 'net/ldap'
#$VERBOSE = true

class Net::LDAP::Entry
  def to_hash
    return @myhash.dup
  end
end

module RubySync::Connectors
  class LdapConnector < RubySync::Connectors::BaseConnector
    
    option  :host,
            :port,
            :bind_method,
            :username,
            :password,
            :search_filter,
            :search_base,
            :association_attribute, # name of the attribute in which to store the association key(s)
            :changelog_dn
            
    association_attribute 'RubySyncAssociation'
    bind_method           :simple
    host                  'localhost'
    port                  389
    search_filter         "cn=*"
    changelog_dn          "cn=changelog"

    def initialize options={}
      super options 
      @last_change_number = 1
    end


    def started
      #TODO: If vault, check the schema to make sure that the association_attribute is there
    end
    
    
    # Look for changelog entries. This is not supported by all LDAP servers
    # you may need to subclass for OpenLDAP and Active Directory
    # Changelog entries have these attributes
    # targetdn
    # changenumber
    # objectclass
    # changes
    # changetime
    # changetype
    # dn
    #
    # TODO: Detect presence/location of changelog from root DSE
    def each_change
      with_ldap do |ldap|
        log.debug "@last_change_number = #{@last_change_number}"
        filter = "(changenumber>=#{@last_change_number})"
        first = true
        @full_refresh_required = false
        ldap.search :base => changelog_dn, :filter =>filter do |change|
          change_number = change.changenumber[0].to_i
          if first
            first = false
            # TODO: Persist the change_number so that we don't do a full resync everytime rubysync starts
            if change_number != @last_change_number
              log.warn "Earliest change number (#{change_number}) differs from that recorded (#{@last_change_number})."
              log.warn "A full refresh is required."
              @full_refresh_required = true
              break
            end
          else
            @last_change_number = change_number if change_number > @last_change_number
            # todo: A proper DN object would be nice instead of string manipulation
            target_dn = change.targetdn[0].gsub(/\s*,\s*/,',')
            if target_dn =~ /#{search_base}$/oi
              change_type = change.changetype[0]
              event = event_for_changelog_entry(change)
              yield event
            end
          end
        end
      end
    end
    

    def each_entry
      Net::LDAP.open(:host=>host, :port=>port, :auth=>auth) do |ldap|
        ldap.search :base => search_base, :filter => search_filter do |entry|
          operations = operations_for_entry(entry)
          association_key = (is_vault?)? nil : entry.dn
          yield RubySync::Event.add(self, entry.dn, association_key, operations)
        end
      end
    end
    
    # Runs the query specified by the config, gets the objectclass of the first
    # returned object and returns a list of its allowed attributes
    def self.fields
      log.warn "Fields method not yet implemented for LDAP - Sorry."
      log.warn "Returning a likely sample set."
      %w{ cn givenName sn }
    end

    
    def stopped
    end
    


    def self.sample_config
      return <<END
   host           'localhost'
   port           10389
   username       'uid=admin,ou=system'
   password       'secret'
   search_filter  "cn=*"
   search_base    "dc=example,dc=com"
   #:bind_method  :simple
  )
END
    end



    def add(path, operations)
      with_ldap do |ldap|
        return false unless ldap.add :dn=>path, :attributes=>perform_operations(operations)
      end
      return true
    rescue Net::LdapException
      log.warning "Exception occurred while adding LDAP record"
      false
    end

    def modify(path, operations)
      log.debug "Modifying #{path} with the following operations:\n#{operations.inspect}"
      with_ldap {|ldap| ldap.modify :dn=>path, :operations=>to_ldap_operations(operations) }
    end

    def delete(path)
      with_ldap {|ldap| ldap.delete :dn=>path }
    end

    def [](path)
      with_ldap do |ldap|
        result = ldap.search :base=>path, :scope=>Net::LDAP::SearchScope_BaseObject, :filter=>'objectclass=*'
        return nil if !result or result.size == 0
        result[0].to_hash
      end
    end
    
    def target_transform event
      event.add_default 'objectclass', 'inetOrgUser'
      # TODO: Add modifier and timestamp unless LDAP dir does this automatically
    end

    def associate_with_foreign_key key, path
      with_ldap do |ldap|
        ldap.add_attribute(path, association_attribute, key.to_s)
      end
    end
    
    def path_for_foreign_key key
      entry = entry_for_foreign_key key
      (entry)? entry.dn : nil
    end
    
    def foreign_key_for path
        entry = self[path]
        (entry)? entry.dn : nil # TODO: That doesn't look right. Should return an association key, not a path.
    end

    def remove_foreign_key key
      with_ldap do |ldap|
        entry = entry_for_foreign_key key
        if entry
          modify :dn=>entry.dn, :operations=>[ [:delete, association_attribute, key] ]
        end
      end
    end

    def find_associated foreign_key
      entry = entry_for_foreign_key key
      (entry)? operations_for_entry(entry) : nil
    end
    

private

    def event_for_changelog_entry cle
      payload = nil
      dn = cle.targetdn[0]
      changetype = cle.changetype[0]
      if cle.attribute_names.include? :changes
        payload = []
        cr = Net::LDIF.parse("dn: #{dn}\nchangetype: #{changetype}\n#{cle.changes[0]}")[0]
        if  changetype.to_sym == :add
          # cr.data will be a hash of arrays or strings (attr-name=>[value1, value2, ...])
          cr.data.each do |name, values|
            payload << RubySync::Operation.add(name, values)
          end
        else
          # cr.data will be an array of arrays of form [:action, :subject, [values]]
          cr.data.each do |record|
            payload << RubySync::Operation.new(record[0], record[1], record[2])
          end
        end
      end
      RubySync::Event.new(changetype, self, dn, nil, payload)
    end
    

    def operations_for_entry entry
      ops = []
      entry.each do |name, values|
        ops << RubySync::Operation.add(name, values)
      end
      ops
    end

    def entry_for_foreign_key key
      with_ldap do |ldap|
        result = ldap.search :base=>search_base, :filter=>"#{association_attribute}=#{key}"
        return nil if !result or result.size == 0
        result[0]
      end
    end


    def with_ldap
      result = nil
      Net::LDAP.open(:host=>host, :port=>port, :auth=>auth) do |ldap|
        result = yield ldap
      end
      result
    end
    
    def auth
      {:method=>bind_method, :username=>username, :password=>password}
    end
    
    # Produce an array of operation arrays suitable for the LDAP library
    def to_ldap_operations operations
      operations.map {|op| [op.type, op.subject, op.values]}
    end
    
  end
end
