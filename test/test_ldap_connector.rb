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

require 'ruby_sync_test'
require 'hashlike_tests'
require 'ruby_sync/connectors/ldap_connector'
require 'ruby_sync/connectors/memory_connector'


class MyLdapConnector < RubySync::Connectors::LdapConnector; end
class MyMemoryConnector < RubySync::Connectors::MemoryConnector; end

class TestPipeline < RubySync::Pipelines::BasePipeline
  
  client :my_ldap,
        :host=>'localhost',
        :port=>10389,
        :username=>'uid=admin,ou=system',
        :password=>'secret',
        :search_filter=>"cn=*",
        :search_base=>"dc=example,dc=com"

  vault :my_memory
  
  allow_out :cn, :givenName, :sn
  
  out_transform do
    if type == :add or type == :modify
      each_operation_on("givenName") { |operation| append operation.same_but_on('cn') }
      append RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson'])
    end
  end

end


class TestLdapConnector < Test::Unit::TestCase
    
  include RubySyncTest
  include HashlikeTests

  def unsynchable
    [:objectclass, :interests, :cn, :dn]
  end



  def path
    'cn=bob,dc=example,dc=com'
  end


  def test_ldap_add
    assert_nil @client[path], "#{path} already exists on client"
    ldap_attr = {
      "objectclass"=>['inetOrgPerson'],
      "cn"=>'bob',
      "sn"=>'roberts',
      "mail"=>"bob@roberts.com"
    }
    @client.add path, @client.create_operations_for(ldap_attr)
    assert_not_nil @client[path], "#{path} wasn't created"
  end

  def test_client_to_vault
  end

end