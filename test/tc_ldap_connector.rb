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


lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync_test'
require 'hashlike_tests'
require 'ruby_sync/connectors/ldap_connector'
require 'ruby_sync/connectors/memory_connector'


class MyLdapConnector < RubySync::Connectors::LdapConnector
  host          'any_ldap'
  port          389
  username      'cn=admin,dc=9to5magic,dc=com,dc=au'
  password      'secret'
  search_filter "cn=*"
  search_base   "dc=9to5magic,dc=com,dc=au"
end

class MyMemoryConnector < RubySync::Connectors::MemoryConnector; end

class LdapTestPipeline < RubySync::Pipelines::BasePipeline
  
  client :my_ldap

  vault :my_memory
  
  allow_out :cn, :givenName, :sn
  
  out_transform do
    if type == :add or type == :modify
      each_operation_on("givenName") { |operation| append operation.same_but_on('cn') }
      append RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson'])
    end
  end

end


class TcLdapConnector < Test::Unit::TestCase
    
  include RubySyncTest
  include HashlikeTests
  
  def testPipeline
    LdapTestPipeline
  end

  def unsynchable
    [:objectclass, :interests, :cn, :dn]
  end


  def vault_path
    # TODO: Try using a different path for the vault that's derived from the client source path
    'cn=bob,ou=users,o=my-organization,dc=my-domain,dc=com'
  end


  def client_path
    'cn=bob,ou=users,o=my-organization,dc=my-domain,dc=com'
  end


  def test_ldap_add
    assert_nil @client[client_path], "#{client_path} already exists on client"
    @client.add client_path, @client.create_operations_for(ldap_attr)
    assert_not_nil @client[client_path], "#{client_path} wasn't created"
  end

  def test_client_to_vault
  end

  private

  def ldap_attr
    {
      "objectclass"=>['inetOrgPerson'],
      "cn"=>'bob',
      "sn"=>'roberts'
      #"mail"=>"bob@roberts.com"
    }
  end
end
