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

#
# Performs end-to-end tests of the memory based testing connectors.
#
lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'test/unit'
require 'ruby_sync/connectors/memory_connector'


class TestConnector < RubySync::Connectors::MemoryConnector
end

class MemoryPipeline < RubySync::Pipelines::BasePipeline
  client :test
  vault :test
end

class TestMemoryConnectors < Test::Unit::TestCase

  def initialize(test)
    super(test)
    @bob_details = { :givenName=>'Robert',
                    :sn=>'Smith',
                    :interests=>['music', 'makeup']
    }
  end
      
  def setup
    @pipeline = MemoryPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault
  end

  
  def test_client_to_vault
    banner "test_client_to_vault"
    @client.add :bob, @bob_details
    assert_nil @vault[:bob], "Vault already contains bob"
    @pipeline.run_once
    assert_equal @bob_details, @vault[:bob]
    @client.delete :bob
    assert_equal @bob_details, @vault[:bob]
    assert_nil @client[:bob], "Bob disappeared from the vault before we ran the pipeline"
    @pipeline.run_once
    assert_nil @vault[:bob], "Bob wasn't deleted from the vault"
  end

  
  def test_vault_to_client
    banner "test_vault_to_client"
    @vault.add :bob, @bob_details
    assert_nil @client[:bob], "Client already contains bob"
    @pipeline.run_once
    assert_equal @bob_details, @client[:bob]
    @vault.delete :bob
    assert_equal @bob_details, @client[:bob]
    assert_nil @vault[:bob], "Bob disappeared from the client before we ran the pipeline"
    @pipeline.run_once
    assert_nil @client[:bob], "Bob wasn't deleted from the client"
  end

  def banner(label)
    puts '*' * 10 + " #{label} " + '*' * 10
  end

  def test_vault
    banner :test_vault
    assert @vault.can_act_as_vault?
    assert @vault.is_vault?
    @vault.add :bob, @bob_details
    @vault.associate_with_foreign_key 'blah', :bob
    assert_equal @bob_details, @vault.entry_for_foreign_key('blah')
    assert_equal 'blah', @vault.foreign_key_for(:bob)
  end

end
    

