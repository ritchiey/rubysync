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

class ActiveRecordTrackingConnector < RubySync::Connectors::ActiveRecordConnector 
  application "#{File.dirname(__FILE__)}/../examples/ar_track"

  changes_model :change_track # Alias of model's method
  associations_model :association_track # Only usefull for vault connector
end

class ArClientConnector < RubySync::Connectors::ActiveRecordConnector
  application "#{File.dirname(__FILE__)}/../examples/ar_client_webapp"
  
  model :user
  path_column :username
  columns :username, :name, :email

#  find_method :all
#  find_filter :conditions => "username LIKE 'b%'"

  find_method :find_chaining
  find_filter 'b', :order => :email
  
  find_chaining do |model, args|
#    model.username_begin_by('b').all(:order => :email, :select => args.first[:select])
    model.username_begin_by(args.first).all(args.second)
  end

  track_with :active_record_tracking
  #  track_changes_with :active_record
  #  track_associations_with :active_record  
end

class ArVaultConnector < RubySync::Connectors::ActiveRecordConnector
  application "#{File.dirname(__FILE__)}/../examples/ar_webapp"

  model :person
  path_column :first_name
  find_method :find_chaining
  set_parse_all_entries false

  find_chaining do |model, args|
    if !parse_all_entries && last_sync_info
      formatted_last_sync = last_sync_info.strftime("%Y-%m-%d %H:%M:%S")
      only_new_and_modified_entries =
       "ruby_sync_events.timestamp >
          '#{formatted_last_sync}'"
    end

    model.
      all(
        :conditions => "#{only_new_and_modified_entries||=nil}",
        :order => "ruby_sync_events.id"
      )
  end
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

  out_event_transform do
    map :username, :first_name
    map :name, :last_name
  end

  # Should evaluate to the path for placing a new record on the vault
#  in_place do
#    {:conditions => {:first_name => source_path}}
#  end

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
    ::ChangeTrack.delete_all
    ::AssociationTrack.delete_all
    ::RubySyncAssociation.delete_all
#    ::RubySyncValue.delete_all
#    ::RubySyncOperation.delete_all
#    ::RubySyncEvent.delete_all
#    ::RubySyncState.delete_all
    ::Person.delete_all
    ::User.delete_all
  end
  
  def test_client_to_vault
    banner "test_client_to_vault"
    ::User.create(@bob_details)
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
    else
      flunk "client must have a 'delete' method"
    end
  end
  
  def test_vault_to_client
    assert_equal 0, ::RubySyncEvent.all(:conditions => "id > #{@vault.last_event_id}").length, "Pre-existing events in queue"
    person = ::Person.create :first_name => "Ritchie", :last_name => "Youn"
    assert_not_nil ::RubySyncEvent.first(:conditions => "id > #{@vault.last_event_id} AND event_type='add'"), "No add event generated"
    @pipeline.run_once
    person.update_attributes :last_name => "Young"
    assert_not_nil ::RubySyncEvent.first(:conditions => "id > #{@vault.last_event_id} AND event_type='modify'"), "No modify event generated"
    @pipeline.run_once
    # Find the association and use the key to look up the record on the client
    key = @vault.association_key_for @pipeline.association_context, person.first_name
    assert_not_nil key, "No association seems to have been created"
    c_person = @client.entry_for_own_association_key key
    assert_not_nil c_person, "Person wasn't created on client from vault; key='#{key}'\nClient contains:\n#{@client.inspect}"
    assert_equal "Ritchie", c_person[:username]
    assert_equal "Young", c_person[:name]
  end

  def find_bob
    ::Person.find_by_first_name "bob"
    #    User.find_by_username "Ritchie"
  end

  def test_fields
    assert_equal(%w{first_name last_name id}.sort, ::ArVaultConnector.fields.sort)
  end
  
end
