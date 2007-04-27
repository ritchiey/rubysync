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

class MyActiveRecordConnector < RubySync::Connectors::ActiveRecordConnector; end
class MyMemoryConnector < RubySync::Connectors::MemoryConnector; end

class TestPipeline < RubySync::Pipelines::BasePipeline
  client :my_memory
  vault :my_active_record, :model=>:person, :application=>"#{File.dirname(__FILE__)}/../examples/ar_webapp"
  
  allow_in :first_name, :last_name
  
  map_client_to_vault :givenName  => :first_name,
                      :sn         => :last_name
                      
end



class TestActiveRecordVault < Test::Unit::TestCase

  include RubySyncTest
  
  def client_path
    'bob'
  end
  
  def vault_path
    @vault.path_for_foreign_key(client_path)
  end

  def initialize(test)
    super(test)
    # Wipe existing database content
    # TODO: Find out how rails does this.
   # Person.delete :all
  #  AssociationKey.delete :all
  end
    
  
  def test_client_to_vault
    banner "test_client_to_vault"
    @client.add client_path, @client.create_operations_for(@bob_details)
 #   assert_nil find_bob, "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil find_bob, "#{vault_path} wasn't created on the vault"
    #assert_equal @bob_details, @vault[vault_path].reject {|k,v| [:modifier,:foreign_key].include? k}
    if @client.respond_to? :delete
      @client.delete client_path
#      assert_equal @bob_details, @vault[vault_path].reject {|k,v| [:modifier,:foreign_key].include? k}
      assert_nil @client[client_path], "Bob wasn't deleted from the client"
      @pipeline.run_once
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil find_bob, "Bob wasn't deleted from the vault"
      @pipeline.run_once # run again in case of echoes
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil find_bob, "Bob reappeared in the vault. He may have been created by an echoed add event"
    end
  end
  
  
  def find_bob
    Person.find_by_first_name "Robert"
  end
end