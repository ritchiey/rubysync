#!/usr/bin/env ruby -w
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
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
#require 'set'
#
#class Set
#  def to_hash
#    #TODO Not ruby 1.9 compliant
#    hash={}
#    self.map{ |k,v| hash[k]=(v.is_a?(Array) and v.size==1) ? v.at(0) : v }
#    hash
#  end
#end

class TcHashComparator < Test::Unit::TestCase

  def setup
    @h1={ "key0"=>"value0", "key1"=>"value1", "key2"=>"value2","key4"=>"value3","key5"=>"value4","key6"=>"value6.2" }
    @h2={ :key1=>"value1.1", :key2=>"value2", :key3=>"value3",:key5=>"value5", :key6=>["value6.1", "value6.2"] }
  end

  def test_deep_diff_hash
    #Deep Diff
    log.info("***deep_diff h1 - h2***")
    log.info(h4=@h1.symbolize_keys.deep_diff(@h2))#old elements

    log.info("***deep_diff h2 - h1***")
    log.info(h5=@h2.deep_diff(@h1.symbolize_keys))#new or modified elements
    log.info("***to replace h1 & h2***")
    log.info(h6=h4.keys & h5.keys)#elements to replace
    log.info("***to remove h1 & h2***")
    log.info(h4.keys - h6)#elements to delete
    log.info("***to create h1 & h2***")
    log.info(h5.keys - h6)#elements to add

    assert_not_equal @h1.symbolize_keys.diff(@h2), h4
    assert_equal("value6.1", h5[:key6])
    assert_nil(h5[:key0])
  end

  def test_deleting_k2
    #1 - result: delete k2
    h1={:k1=>'v1',:k2=>'v2'}
    h2={:k1=>'v1'}
    assert_equal(:k2,delete_elements(h1,h2).at(0))
    assert_nil(add_elements(h1,h2).at(0))
    log.debug new_elements(h1,h2).inspect
    log.debug old_elements(h1,h2).inspect
    assert_nil(replace_elements(h1,h2).at(0))
  end
       
  def test_adding_k2
    #2 - result: add k2
    h1={:k1=>'v1'}
    h2={:k1=>'v1',:k2=>'v2'}
    assert_equal(:k2,add_elements(h1,h2).at(0))
    assert_nil(delete_elements(h1,h2).at(0))
    assert_nil(replace_elements(h1,h2).at(0))
  end

  def test_adding_k3
    #3 - result: add k3
    h1={:k1=>'v1',:k2=>'v2'}
    h2={:k1=>'v1',:k2=>'v2',:k3=>'v3'}
    assert_equal(:k3,add_elements(h1,h2).at(0))
    assert_nil(delete_elements(h1,h2).at(0))
    assert_nil(replace_elements(h1,h2).at(0))
  end

  def test_replacing_k1_by_k2
    #4 - result: replace k1 by k2
    h1={:k1=>'v1'}
    h2={:k1=>'v2'}
    assert_nil(add_elements(h1,h2).at(0))
    assert_nil(delete_elements(h1,h2).at(0))
    assert_equal(:k1,replace_elements(h1,h2).at(0))
  end

  def test_adding_k3_and_deleting_k1
    #5 - result: add k3, delete k1 or replace k1 by k3
    h1={:k1=>'v1',:k2=>'v2'}
    h2={:k2=>'v2',:k3=>'v3'}
    assert_equal(:k3,add_elements(h1,h2).at(0))
    assert_equal(:k1,delete_elements(h1,h2).at(0))
    assert_nil(replace_elements(h1,h2).at(0))
  end

  def test_adding_in_k1_value_v3
    #6 - result: add value :k1 => 'v3'
    h1={:k1=>'v1',:k2=>'v2'}
    h2={:k2=>'v2',:k1=>['v1','v3']}
    assert_equal(:k1,add_elements(h1,h2).at(0))
    assert_equal(nil,delete_elements(h1,h2).at(0))
    assert_equal(nil,replace_elements(h1,h2).at(0))
    assert_equal('v3', new_elements(h1,h2)[:k1])
  end

  def test_deleting_in_k1_value_v1_1
    #7 - result: delete value :k1 => 'v1.1'
    h1 = {:k1=>['v1','v1.1'],:k2=>'v2'}
    h2 = {:k2=>'v2',:k1=>'v1'}
    assert_equal(nil,add_elements(h1,h2).at(0))
    assert_equal(:k1,delete_elements(h1,h2).at(0))
    assert_equal(nil,replace_elements(h1,h2).at(0))
    assert_equal('v1.1', old_elements(h1,h2)[:k1])
    assert_equal(nil, new_elements(h1,h2)[:k1])
  end

  def test_deleting_in_k1_value_v1_2
    #8 - result: delete value :k1 => 'v1.2'
    h1 = {:k1=>['v1','v1.1','v1.2'],:k2=>'v2'}
    h2 = {:k2=>'v2',:k1=>['v1','v1.1']}
    assert_equal(nil,add_elements(h1,h2).at(0))
    assert_equal(:k1,delete_elements(h1,h2).at(0))
    assert_equal(nil,replace_elements(h1,h2).at(0))
    assert_equal('v1.2', old_elements(h1,h2)[:k1])
    assert_equal(nil, new_elements(h1,h2)[:k1])
  end

  def test_adding_in_k1_value_v1_2
    #9 - result: add value :k1 => 'v1.2'
    h1 = {:k1 => ['v1','v1.1'],:k2 => 'v2'}
    h2 = {:k2 => 'v2',:k1 => ['v1','v1.1','v1.2']}
    assert_equal(:k1,add_elements(h1,h2).at(0))
    assert_equal(nil,delete_elements(h1,h2).at(0))
    assert_equal(nil,replace_elements(h1,h2).at(0))
    assert_equal(nil, old_elements(h1,h2)[:k1])
    assert_equal('v1.2', new_elements(h1,h2)[:k1])

    add_elements(h1,h2).each do |key|
      log.debug(key)
      log.debug(new_elements(h1,h2))
      new_elements(h1,h2)[key].each do |value|
        assert_equal('v1.2',  value)
        log.debug(value)
      end
    end
  end

  def test_replacing_in_k1_deleting_values_v1_1_and_v1_2_and_adding_value_v1_3
    #10 - result: replace :k1 (delete value :k1 => ['v1.1','v1.2'] and add value :k1 => 'v1.3')
    h1 = {:k1=>['v1','v1.1','v1.2'],:k2=>'v2'}
    h2 = {:k2=>'v2',:k1=>['v1','v1.3']}
    assert_equal(nil,add_elements(h1,h2).at(0))
    assert_equal(nil,delete_elements(h1,h2).at(0))
    assert_equal(:k1,replace_elements(h1,h2).at(0))
    assert_equal(['v1.1','v1.2'], old_elements(h1,h2)[:k1])
    assert_equal('v1.3', new_elements(h1,h2)[:k1])
  end

  def test_replacing_in_k1_deleting_values_v1_v1_1_and_v1_2_and_adding_value_v1_3
    #11 - result: replace :k1 (delete value :k1 => ['v1','v1.1','v1.2'] and add value :k1 => 'v1.3')
    h1 = {:k1=>['v1','v1.1','v1.2'],:k2=>'v2'}
    h2 = {:k2=>'v2',:k1=>'v1.3'}
    assert_equal(nil,add_elements(h1,h2).at(0))
    assert_equal(nil,delete_elements(h1,h2).at(0))
    assert_equal(:k1,replace_elements(h1,h2).at(0))
    assert_equal(['v1','v1.1','v1.2'], old_elements(h1,h2)[:k1])
    assert_equal('v1.3', new_elements(h1,h2)[:k1])
  end

  def test_replacing_in_k1_adding_values_v1_v1_1_and_v1_2_and_deleting_value_v1_3
    #12 - result: replace :k1 (add value :k1 => ['v1',v1.1','v1.2'] and delete value :k1 => 'v1.3')
    h1 = {:k1=>'v1.3',:k2=>'v2'}
    h2 = {:k2=>'v2',:k1=>['v1','v1.1','v1.2']}
    assert_equal(nil,add_elements(h1,h2).at(0))
    assert_equal(nil,delete_elements(h1,h2).at(0))
    assert_equal(:k1,replace_elements(h1,h2).at(0))
    assert_equal('v1.3', old_elements(h1,h2)[:k1])
    assert_equal(['v1','v1.1','v1.2'], new_elements(h1,h2)[:k1])
  end 

  #Helpers
  
  def old_elements(h1,h2)
    h1.symbolize_keys.deep_diff(h2.symbolize_keys)
  end

  def new_elements(h1,h2)
    h2.symbolize_keys.deep_diff(h1.symbolize_keys)
  end
  
  def replace_elements(h1, h2)
    new_elements(h1,h2).keys & old_elements(h1,h2).keys
  end

  def add_elements(h1, h2)
    new_elements(h1, h2).keys - replace_elements(h1, h2)
  end

  def delete_elements(h1,h2)
    old_elements(h1, h2).keys - replace_elements(h1, h2)
  end

  #  def test_restore_hash
  #    h3=to#  _hash(to_a(@h2))
  #    assert_equal @h2, h3
  #  end
  #
  #  # Returns an array of a hash who has symbolize keys
  #  def to_a(hash)
  #    hash.symbolize_keys.to_a.flatten
  #  end
  #
  #  # Returns a hash of an array where keys are symbolize values
  #  def to_hash(array)
  #    hash={}
  #    h=nil#last_key_found
  #    array.map do |v|
  #      if(v.is_a? Symbol)
  #       h=v
  #      else
  #        (hash[h])? hash[h] = hash[h].to_a << v: hash[h]=v
  #      end
  #    end
  #    hash
  #  end
end
