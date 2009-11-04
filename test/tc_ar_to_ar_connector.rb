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


[  File.dirname(__FILE__) + '/../lib', File.dirname(__FILE__)
].each {|path| $:.unshift path unless $:.include?(path) || $:.include?(File.expand_path(path))}

require 'ruby_sync_test'

class ArTrackConnector < RubySync::Connectors::ActiveRecordConnector
  #  model :change_track
  changes_model :change_track#Alias of model's method
  associations_model :association_track#Only usefull for vault connector
  application "#{File.dirname(__FILE__)}/../examples/ar_track"
end

class ArClientConnector < RubySync::Connectors::ActiveRecordConnector
  model :user
  application "#{File.dirname(__FILE__)}/../examples/ar_client_webapp"
  track_with :ar_track
  #  track_changes_with :active_record
  #  track_associations_with :active_record
end

class ArVaultConnector < RubySync::Connectors::ActiveRecordConnector
  model :person
  application "#{File.dirname(__FILE__)}/../examples/ar_webapp"
end

class ArToArTestPipeline < RubySync::Pipelines::BasePipeline

  client :ar_client
  vault :ar_vault
    
  allow_in :username, :name, :email
  allow_out :first_name, :last_name
 
  in_event_transform do
    map :first_name, :username
    map :last_name, :name
  end

  # Should evaluate to the path for placing a new record on the vault
  in_place do
    {:conditions => {:first_name => source_path}}
  end

end

class TcArToArConnector < Test::Unit::TestCase

  include RubySyncTest
  
  def client_path
    {:conditions => {:username => 'bob'}}
    #    {:conditions => {:first_name => 'Ritchie'}}
  end
  
  def vault_path
    @vault.path_for_association(RubySync::Association.new(@pipeline.association_context, self.client_path)) 
  end

  def initialize(test)
    super(test)
  end
    
  def setup
    @pipeline = ArToArTestPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault
    #    @pipeline.run_once
    @bob_details = {:username=>'bob', :name=>'Robert',:email=>'bob.robert@localhost'}
    # Wipe existing database content
    # TODO: Find out how rails does this.
    ::RubySyncAssociation.delete_all
    ::Person.delete_all
    ::User.delete_all
  end
  
  def test_client_to_vault
    banner "test_client_to_vault"
    User.create(@bob_details)
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
      assert_nil find_bob, "Bob reappeared in the vault. He may have been created by an echoes add event"
    end
  end
  
  #  def test_vault_to_client
  #    # Turn on the RubySyncObserver to track the changes to people
  #    ActiveRecord::Base.observers = ::RubySyncObserver
  #     ::RubySyncObserver.observe ::Person
  #     ::RubySyncObserver.instance
  #     assert_nil ::RubySyncEvent.find(:first), "Pre-existing events in queue"
  #     person = Person.create :first_name=>"Ritchie", :last_name=>"Young"
  #     assert_not_nil ::RubySyncEvent.find_by_event_type('add'), "No add event generated"
  #     @pipeline.run_once
  #    # Find the association and use the key to look up the record on the client
  #    key = @vault.association_key_for @pipeline.association_context, person.id
  #    assert_not_nil key, "No association seems to have been created"
  #    c_person = @client.entry_for_own_association_key key
  #    assert_not_nil c_person, "Person wasn't created on client from vault; key='#{key}'\nClient contains:\n#{@client.inspect}"
  #    assert_equal "Ritchie", c_person['username']
  #    assert_equal "Young", c_person['name']
  #     ActiveRecord::Base.observers = [] # Stop tracking changes to people
  #  end

  def find_bob
    Person.find_by_first_name "bob"
    #    User.find_by_username "Ritchie"
  end

  def test_fields
    assert_equal(%w{first_name last_name}.sort, ::ArVaultConnector.fields.sort)
  end
  
end
