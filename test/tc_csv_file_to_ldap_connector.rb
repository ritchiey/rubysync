#!/usr/bin/env ruby
#
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

lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift lib_path unless $:.include?(lib_path)

require 'ruby_sync_test'
require 'ruby_sync/connectors/file_connector'
require 'ruby_sync/connectors/csv_file_connector'
require 'ruby_sync/connectors/ldap_connector'
require 'csv'


class TestCsvConnector < RubySync::Connectors::CsvFileConnector
#  dbm_path "/tmp/rubysync_csv"  
  field_names ['id', 'given name', 'last name', 'email']
  path_field  'id'
  in_path     File.expand_path("~/rubysync/csv_to_ldap_test/in")
  out_path    File.expand_path("~/rubysync/csv_to_ldap_test/out")
  header_line false
end

class TestLdapConnector < RubySync::Connectors::LdapConnector
#  dbm_path "/tmp/rubysync_memory"

  # ApacheDS config
  host          'localhost'
  port          10389
  username      'uid=admin,ou=system'
  password      'secret'
  #changelog_dn  'cn=changelog,ou=schema'
  search_filter "cn=*"
  search_base   "ou=users,ou=system"

  # OpenLDAP config
#  host          'localhost'
#  port          389
#  username      'cn=admin,dc=localhost'
#  password      'secret'
#  #changelog_dn  'cn=changelog'
#  search_filter 'cn=*'
#  search_base   'dc=localhost'

end

class CsvToLdapTestPipeline < RubySync::Pipelines::BasePipeline

  client :test_csv
         
  vault :test_ldap
  
  allow_in :id, 'given name', 'last name', :email
  #allow_out :cn, :giveName, :sn, :mail
  
  in_event_transform do
    map :cn, :id
    map :givenname, 'given name'
    map :sn, 'last name'
    map :mail, :email
    map(:objectclass) { %w(inetOrgPerson organizationalPerson person top) }

  end

  # Should evaluate to the path for placing a new record on the vault
  in_place do
#    "cn=#{source_path},dc=localhost"#OpenLDAP
    "cn=#{source_path},ou=users,ou=system"#ApacheDS
  end
end

class TcCsvToLdapConnector < Test::Unit::TestCase
  
  include RubySyncTest

  def unsynchable
    [:modifier, :objectclass, :rubysyncassociation]
  end 
  
  def vault_path
#    'cn=bob,dc=localhost'#OpenLDAP
    'cn=bob,ou=users,ou=system'#ApacheDS
  end

  def setup
    @pipeline = CsvToLdapTestPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault

    @filename = "#{@client.in_path}/client_to_vault.csv"
    File.delete @filename if File.exists? @filename
    @pipeline.run_once # create the in and out directories if necessary
    @bob_details = {:cn=>'bob', :givenName=>"Robert", :sn=>"Smith", :mail=>'bob@thecure.com'}
  end

  def test_client_to_vault
    #@vault.delete(vault_path)#debug
    banner :test_client_to_vault
    CSV.open(@filename, 'w') do |csv|
      csv << [:cn, :givenName, :sn, :mail].collect {|key| @bob_details[key]}
    end
    assert_nil @vault[vault_path], "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil @vault[vault_path], "Bob wasn't created in vault"
    
    assert_equal normalise(@bob_details), normalise(@vault[vault_path])
    @pipeline.run_once
    
    @bob_details[:givenName] = 'Roberto'
    @bob_details[:sn]= "Smitho"
      
    CSV.open(@filename, 'w') do |csv|
      csv << [:cn, :givenName, :sn, :mail].collect {|key| @bob_details[key]}
    end
    @pipeline.run_once
    assert_equal normalise(@bob_details), normalise(@vault[vault_path])

    @vault.delete(vault_path)
    assert_nil @vault[vault_path], "Bob wasn't deleted in vault"
  end

  def normalise details
    normal = {}
    @unsynchable ||= unsynchable.map{|u| u.to_s.downcase}
    details.each_pair do |k,v|
      key = k.to_s.downcase
      unless @unsynchable.include?(key)
        normal[key] = v
#        puts "[#{@unsynchable.join ','}] doesn't include '#{key}'"
      end
    end
    normal.keys.sort_by {|s| s.to_s}.map {|key| [key, normal[key]] }.to_s #sort hash by keys and convert it to string
  end

end