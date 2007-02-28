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


# Tests that assume that the connectors can be treated like hashes. That is, they can be accessed
# using the []  and []= operators.
module HashlikeTests
  
  

  
   # Override this if :bob isn't a good path for your directory
  def path
    :bob
  end
  
  def test_client_to_vault
    banner "test_client_to_vault"
    @client.add path, @client.create_operations_for(@bob_details)
    assert_nil @vault[path], "Vault already contains bob"
    @pipeline.run_once
    assert_equal @bob_details, @vault[path].reject {|k,v| [:modifier,:foreign_key].include? k}
    if @client.respond_to? :delete
      @client.delete path
      assert_equal @bob_details, @vault[path].reject {|k,v| [:modifier,:foreign_key].include? k}
      assert_nil @client[path], "Bob wasn't deleted from the client"
      @pipeline.run_once
      assert_nil @client[path], "Bob reappeared on the client"
      assert_nil @vault[path], "Bob wasn't deleted from the vault"
      @pipeline.run_once # run again in case of echoes
      assert_nil @client[path], "Bob reappeared on the client"
      assert_nil @vault[path], "Bob reappeared in the vault. He may have been created by an echoed add event"
    end
  end


  def test_vault_to_client
    banner "test_vault_to_client"
    @vault.add path, @vault.create_operations_for(@bob_details)
    assert_nil @client[path], "Client already contains bob"
    @pipeline.run_once
    assert_not_nil @client[path], "#{path} wasn't created on the client"
    assert_equal @bob_details, @client[path].reject {|k,v| k == :modifier}
    @vault.delete path
    assert_equal @bob_details, @client[path].reject {|k,v| k == :modifier}
    assert_nil @vault[path], "Bob disappeared from the client before we ran the pipeline"
    @pipeline.run_once
    assert_nil @client[path], "Bob wasn't deleted from the client"
    @pipeline.run_once # run again in case there were unhandled echos
    assert_nil @client[path], "Bob is back in client, he may have been recreated by an echoed add event"
  end


  def test_vault
    banner :test_vault
    assert @vault.can_act_as_vault?
    assert @vault.is_vault?
    @vault.add path, @vault.create_operations_for(@bob_details)
    @vault.associate_with_foreign_key 'blah', path
    assert_equal path, @vault.path_for_foreign_key('blah')
    assert_equal 'blah', @vault.foreign_key_for(path)
  end

  def test_perform_operations
    banner :test_perform_operations
    result = @vault.perform_operations [
      [:add, :name, 'Fred'],
      [:add, :email, 'fred@test.com']
      ]
    assert_equal({:name=>['Fred'], :email=>['fred@test.com']}, result)
  end
end