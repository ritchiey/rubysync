#!/usr/bin/env ruby
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
#  Copyright (c) 2009 Nowhere Man
#
# This file is part of RubySync.
#
# RubySync is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# RubySync is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with RubySync; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) ||
  $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'net/ldif'
$VERBOSE = false
require 'net/ldap'
#$VERBOSE = true


class Net::LDAP::Entry
  def to_hash
    @myhash.dup
  end
end

module RubySync::Connectors
  class LdapConnector < RubySync::Connectors::BaseConnector

    include LdapAssociationTracking

    option  :host,
      :port,
      :bind_method,
      :encryption,
      :username,
      :password,
      :search_filter,
      :search_base,
      :attributes,
      :association_attribute # name of the attribute in which to store the association key(s)

    association_attribute 'RubySyncAssociation'
    bind_method           :simple
    host                  'localhost'
    port                  10389
    #port                  389
    search_filter         "cn=*"
    encryption		 nil

    def initialize options={}
      super options
    end


    def started
      #TODO: If vault, check the schema to make sure that the association_attribute is there
      @connections = []
      @connection_index = 0
    end


    def each_entry
      Net::LDAP.open(:host=>host, :port=>port, :auth=>auth) do |ldap|
	      ldap.search search_args(:return_result => false) do |ldap_entry|
	        yield to_entry(ldap_entry)
	      end
      end
    end

    # Runs the query specified by the config, gets the objectclass of the first
    # returned object and returns a list of its allowed attributes
    def self.fields
      return @attributes if @attributes
      log.warn ":attributes option not set"
      log.warn "Returning a likely sample set."
      %w{ cn givenName sn }
    end



    def self.sample_config
      return <<END

  # Using :memory is ok for testing.
  # For production, you will need to change to a persistent form of tracking
  # such as :dbm or :ldap. 
  track_changes_with :memory
  track_associations_with :memory

  host           'localhost'
  port            389
  username       'cn=Manager,dc=my-domain,dc=com'
  password       'secret'
  search_filter  "cn=*"
  #attributes     :cn, :sn, :objectclass
  search_base    "ou=users,o=my-organization,dc=my-domain,dc=com"
  #bind_method  :simple
   
  #Uncomment the following for LDAPS. If you do, make sure that
  #you're using the LDAPS port (probably 636) and be aware that
  #the server's certificate WON'T be checked for validity.
  #encryption	 :simple_tls
END
    end



    def add(path, operations)
      result = nil
      with_ldap do |ldap|
        operations << RubySync::Operation.add('objectclass', RUBYSYNC_ASSOCIATION_CLASS)
        attributes = perform_operations(operations)
        attributes['objectclass'] || log.warn("Add without objectclass attribute is unlikely to work.")
        result = ldap.add :dn=>path, :attributes=>attributes
      end
      log.debug("ldap.add returned '#{result}'")
      return result
      rescue Exception
      log.warn "Exception occurred while adding LDAP record"
      log.debug $!
      false
    end

    def modify(path, operations)
      #log.debug "Modifying #{path} with the following operations:\n#{operations.inspect}"
      with_ldap do |ldap|
        operations.each do |op|          
          if op.subject == 'objectclass' and op.type == :replace
            found=false
            op.values.each { |value| found=true if value == RUBYSYNC_ASSOCIATION_CLASS}
            op.values << RUBYSYNC_ASSOCIATION_CLASS unless found
          end
        end
        
        unless ldap.modify :dn=>path, :operations=>to_ldap_operations(operations)
          log.warn "Ldap Modification fails:  #{ldap.get_operation_result.message}"#debug
        end
      end
    end

    def delete(path)
      with_ldap {|ldap| ldap.delete :dn=>path }
    end

    def [](path)
      with_ldap do |ldap|
	      result = ldap.search search_args(:base=>path, :scope=>Net::LDAP::SearchScope_BaseObject, :filter=>'objectclass=*')
        return nil if !result or result.size == 0
        answer = {}
        result[0].attribute_names.each do |name|
	        name = name.to_s.downcase
	        answer[name] = result[0][name] unless name == 'dn'
        end
	    answer
    end
  end

    def search_args(extras={})
      args = {:base => search_base, :filter => search_filter}
      @attributes and args[:attributes] = @attributes
      args.merge(extras)
    end


    # Called by unit tests to inject data
    def test_add id, details
      details << RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson'])
      add id, details
    end

    def target_transform event
      #event.add_default 'objectclass', 'inetOrgUser'
#      if is_vault?
#        event.payload.each do |op|
#          if op.subject=='objectclass' and op.values.to_s==RUBYSYNC_ASSOCIATION_CLASS
#            event.add_value 'objectclass', RUBYSYNC_ASSOCIATION_CLASS
#          end
#        end
#      end
    end



    private

    def to_entry ldap_entry
      entry = {}
      ldap_entry.each do |name, values|
        entry[name.to_s] =  values.map {|v| String.new(v)} 
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
      connection_options = {:host=>host, :port=>port, :auth=>auth}
      connection_options[:encryption] = encryption if encryption
      started unless @connection_index #debug
      @connections[@connection_index] = Net::LDAP.new(connection_options) unless @connections[@connection_index]
      if @connections[@connection_index]
        ldap = @connections[@connection_index]
        @connection_index += 1
        result = yield ldap
        @connection_index -= 1
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
