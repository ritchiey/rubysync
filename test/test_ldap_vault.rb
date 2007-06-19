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


class MyLdapConnector < RubySync::Connectors::LdapConnector
  host        '10.1.1.4'
  port        389
  username    'cn=directory manager'
  password    'password'
  changelog_dn 'cn=changelog'
  search_filter "cn=*"
  search_base   "ou=people,dc=9to5magic,dc=com,dc=au"
  
  def initialize options={}
    super(options)
    skip_existing_changelog_entries
  end

end

class MyMemoryConnector < RubySync::Connectors::MemoryConnector; end

class TestPipeline < RubySync::Pipelines::BasePipeline
  
  client :my_memory

  vault :my_ldap
  
  allow_out :cn, :givenName, :sn
  allow_in :cn, :givenName, :sn, :objectclass
  
  def in_place(event)
    event.target_path = "cn=#{event.source_path},ou=people,dc=9to5magic,dc=com,dc=au"
  end
  
  def out_place(event)
    event.target_path =~ /cn=(.+?),/oi
    event.source_path = $1
  end
  
  in_transform do
    if type == :add or type == :modify
      each_operation_on("givenName") { |operation| append operation.same_but_on('cn') }
      append RubySync::Operation.new(:add, "objectclass", ['inetOrgPerson', 'organizationalPerson', 'person', 'top', 'RubySyncSynchable'])
    end
  end

end


class TestLdapVault < Test::Unit::TestCase

  include RubySyncTest
  include HashlikeTests
 
  
  def unsynchable
    ["objectclass", "interests", "cn", "dn", "rubysyncassociation"]
  end  
  
  def client_path
    'bob'
  end
  
  def vault_path
    'cn=bob,ou=people,dc=9to5magic,dc=com,dc=au'
  end


end