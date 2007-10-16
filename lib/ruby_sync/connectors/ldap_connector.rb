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
    :association_attribute # name of the attribute in which to store the association key(s)
            
    association_attribute 'RubySyncAssociation'
    bind_method           :simple
    host                  'localhost'
    port                  389
    search_filter         "cn=*"

    def initialize options={}
      super options
    end


    def started
      #TODO: If vault, check the schema to make sure that the association_attribute is there
    end
    

    def each_entry
      Net::LDAP.open(:host=>host, :port=>port, :auth=>auth) do |ldap|
        ldap.search :base => search_base, :filter => search_filter, :return_result => false do |ldap_entry|
          yield ldap_entry.dn, to_entry(ldap_entry)
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
    


    def self.sample_config
      return <<END
      
   host           'localhost'
   port            389
   username       'cn=Manager,dc=my-domain,dc=com'
   password       'secret'
   search_filter  "cn=*"
   search_base    "ou=users,o=my-organization,dc=my-domain,dc=com"
   #:bind_method  :simple
END
    end



    def add(path, operations)
      result = nil
      with_ldap do |ldap|
        attributes = perform_operations(operations)
        result = ldap.add :dn=>path, :attributes=>attributes
      end
      log.debug("ldap.add returned '#{result}'")
      return true
    rescue Exception
      log.warn "Exception occurred while adding LDAP record"
      log.debug $!
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
        answer = {}
        result[0].attribute_names.each do |name|
          answer[name.to_s] = result[0][name]
        end
        answer
      end
    end
    
    # Called by unit tests to inject data
    def test_add id, details
      details << RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson'])
      add id, details
    end
    
    def target_transform event
      #event.add_default 'objectclass', 'inetOrgUser'
      #is_vault? and event.add_value 'objectclass', RUBYSYNC_ASSOCIATION_CLASS
    end



    private

    def to_entry ldap_entry
      entry = {}
      ldap_entry.each do |name, values|
        entry[name.to_s] = values.map {|v| String.new(v)}
      end
      entry
    end

    def operations_for_entry entry
      ops = []
      entry.each do |name, values|
        ops << RubySync::Operation.add(name, values)
      end
      ops
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
