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

#
# Tests transformation operations in the Event class
#
[File.dirname(__FILE__) + '/../lib', File.dirname(__FILE__)].each do |lib_path|
  $:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))
end
require 'ruby_sync_test'
require 'ruby_sync/connectors/xml_connector'


class TransformationVaultConnector < RubySync::Connectors::MemoryConnector
  dbm_path "/tmp/rubysync_xml"
end

class TransformationClientConnector < RubySync::Connectors::MemoryConnector
  dbm_path "/tmp/rubysync_memory"
end


class TransformationTestPipeline < RubySync::Pipelines::BasePipeline
  client :transformation_vault
  vault :transformation_client
  
  allow_in :givenName, :sn, :interests
  allow_out :first_name, :last_name
  
  in_transform do
   map :first_name, :givenName
   map :last_name, :sn
   # Calculated value
   map(:hobbies) {values_for(:interests).join ':'}
   # Constant string
   map(:note) {"Created by RubySync"}
   map(:shopping) {%w/fish milk bread/}
   # Conditional mapping
   map(:password) {value_for(:givenName)} if type == :add
  end
  
  in_place { "#{self.source_path}/path/in/vault"}
  out_place { "#{self.source_path}".split('/')[0] }
end

class TcTransformation < Test::Unit::TestCase
  
  include RubySyncTest


  def client_path() 'bob'; end
  def vault_path() 'bob/path/in/vault'; end
  
  def testPipeline
    TransformationTestPipeline
  end
  
  def test_transform
    @client[client_path] = @bob_details
    @pipeline.run_once
    assert_not_nil @vault[vault_path],"Bob wasn't created on the vault"
    assert_equal @bob_details['givenName'], @vault[vault_path]['first_name']
    assert_equal @bob_details['sn'], @vault[vault_path]['last_name']
    assert_equal "Created by RubySync", @vault[vault_path]['note'][0]
    assert_equal "music:makeup", @vault[vault_path]['hobbies'][0]
    assert_equal %w/fish milk bread/, @vault[vault_path]['shopping']
    assert_equal @bob_details['givenName'], @vault[vault_path]['password']
    @vault[vault_path]['password'] = new_password = 'myNewPassword'
    assert_equal new_password, @vault[vault_path]['password']
    @client[client_path]['givenName'] = new_given_name = 'Mary'
    @pipeline.run_once
    assert_equal [new_given_name], @vault[vault_path]['first_name']
    assert_equal new_password, @vault[vault_path]['password']
  end
  
end
