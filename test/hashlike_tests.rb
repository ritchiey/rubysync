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


# Tests that assume that the connectors can be treated like hashes. That is, they can be accessed
# using the []  and []= operators.
module HashlikeTests
  
   # Override this if :bob isn't a good path for your directory
  # def path
  #   :bob
  # end
  
  def client_path
    'bob'
  end
  
  def vault_path
    'bob'
  end
  
  def test_client_to_vault
    banner "test_client_to_vault"
    assoc_key = @client.add client_path, @client.create_operations_for(@bob_details)
    assert_not_nil @client.entry_for_own_association_key(assoc_key)
    assert_nil @vault[vault_path], "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil @vault[vault_path], "#{vault_path} wasn't created on the vault"
    assert_equal @bob_details, @vault[vault_path].reject {|k,v| ['modifier',:association].include? k}
    if @client.respond_to? :delete
      @client.delete client_path
      assert_equal @bob_details, @vault[vault_path].reject {|k,v| ['modifier',:association].include? k}
      assert_nil @client[client_path], "Bob wasn't deleted from the client"
      @pipeline.run_once
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil @vault[vault_path], "Bob wasn't deleted from the vault"
      @pipeline.run_once # run again in case of echoes
      assert_nil @client[client_path], "Bob reappeared on the client"
      assert_nil @vault[vault_path], "Bob reappeared in the vault. He may have been created by an echoed add event"
    end
  end


  def test_vault_to_client
    banner "test_vault_to_client"
    @vault.add vault_path, @vault.create_operations_for(@bob_details)
    assert_nil @client[client_path], "Client already contains bob"
    @pipeline.run_once
    assert_not_nil @client[client_path], "#{client_path} wasn't created on the client"
    assert_equal normalise(@bob_details), normalise(@client[client_path])
    @vault.delete vault_path
    assert_equal normalise(@bob_details), normalise(@client[client_path])
    assert_nil @vault[vault_path], "Bob wasn't deleted from the vault"
    assert_not_nil @client[client_path], "Bob was deleted from the client before we ran the pipe"
    @pipeline.run_once
    assert_nil @client[client_path], "Bob wasn't deleted from the client"
    @pipeline.run_once # run again in case there were unhandled echos
    assert_nil @client[client_path], "Bob is back in client, he may have been recreated by an echoed add event"
  end

  # Names of attributes that can't be synched
  def unsynchable
    [:modifier]
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
    normal
  end


  def test_vault
    banner :test_vault
    assert @vault.can_act_as_vault?
    assert @vault.is_vault?
    @vault.add vault_path, @vault.create_operations_for(@bob_details)
    association = RubySync::Association.new(@pipeline.association_context, 'blah')
    @vault.associate association, vault_path
    assert_equal vault_path, @vault.path_for_association(association)
    assert_equal 'blah', @vault.association_key_for(@pipeline.association_context, vault_path)
  end

  def test_perform_operations
    banner :test_perform_operations
    result = @vault.perform_operations [
      RubySync::Operation.new(:add, :name, 'Fred'),
      RubySync::Operation.new(:add, :email, 'fred@test.com')
      ]
    assert_equal({'name'=>['Fred'], 'email'=>['fred@test.com']}, result)
  end
end