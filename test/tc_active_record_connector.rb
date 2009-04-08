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

class ArActiveRecordConnector < RubySync::Connectors::ActiveRecordConnector
  option :dbm_path
  model :person
    application "../../../examples/ar_webapp"
    dbm_path "/tmp/rubysync_ar_test"
end

class ArMemoryConnector < RubySync::Connectors::MemoryConnector
  option :dbm_path
  dbm_path "/tmp/rubysync_memory_test"
end

class ArTestPipeline < RubySync::Pipelines::BasePipeline
  client :ar_memory
  vault :ar_active_record
  
  allow_in :givenName, :sn
  allow_out :first_name, :last_name
 
  in_event_transform do
    map :first_name, :givenName
    map :last_name, :sn 
  end

  out_event_transform do
    map :givenName, :first_name
    map :sn, :last_name 
  end

end



class TcActiveRecordConnector < Test::Unit::TestCase

  include RubySyncTest

  def testPipeline
    ArTestPipeline
  end  
  
  def client_path
    'bob'
  end
  
  def vault_path
    @vault.path_for_association(RubySync::Association.new(@pipeline.association_context, self.client_path))
  end

  def initialize(test)
    super(test)
  end
    
    def setup
      super
      # Wipe existing database content
      # TODO: Find out how rails does this.
      ::RubySyncAssociation.delete_all
      ::Person.delete_all
    end
  
  def test_client_to_vault
    banner "test_client_to_vault"
    @client.add client_path, @client.create_operations_for(@bob_details)
    assert_nil find_bob, "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil find_bob, "#{vault_path} wasn't created on the vault"
    #assert_equal @bob_details, @vault[vault_path].reject {|k,v| [:modifier,:association].include? k}
    if @client.respond_to? :delete
      @client.delete client_path
#      assert_equal @bob_details, @vault[vault_path].reject {|k,v| [:modifier,:association].include? k}
      assert_nil @client[client_path], "Bob wasn't deleted from the client"
      @pipeline.run_once
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil find_bob, "Bob wasn't deleted from the vault"
      @pipeline.run_once # run again in case of echoes
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil find_bob, "Bob reappeared in the vault. He may have been created by an echoed add event"
    end
  end
  
  def test_vault_to_client
    # Turn on the RubySyncObserver to track the changes to people
      ActiveRecord::Base.observers = ::RubySyncObserver
      ::RubySyncObserver.observe ::Person
      ::RubySyncObserver.instance
      assert_nil ::RubySyncEvent.find(:first), "Pre-existing events in queue"
      person = ::Person.create :first_name=>"Ritchie", :last_name=>"Young"

     assert_not_nil ::RubySyncEvent.find_by_event_type('add'), "No add event generated"
     @pipeline.run_once
    # Find the association and use the key to look up the record on the client
    key = @vault.association_key_for @pipeline.association_context, person.id
    assert_not_nil key, "No association seems to have been created"
    c_person = @client.entry_for_own_association_key key
    assert_not_nil c_person, "Person wasn't created on client from vault; key='#{key}'\nClient contains:\n#{@client.inspect}"
    assert_equal "Ritchie", c_person['givenName'][0]
    assert_equal "Young", c_person['sn'][0]
     ActiveRecord::Base.observers = [] # Stop tracking changes to people
  end
  
  def find_bob
    ::Person.find_by_first_name "bob"
  end
  
  def test_fields
    assert_equal(%w{first_name last_name}.sort, ::ArActiveRecordConnector.fields.sort)
  end
  
end