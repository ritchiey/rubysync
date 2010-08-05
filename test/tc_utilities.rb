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


[  File.dirname(__FILE__) + '/../lib', File.dirname(__FILE__)
].each {|path| $:.unshift path unless $:.include?(path) || $:.include?(File.expand_path(path))}

require 'ruby_sync'
require 'test/unit'

RIGHT = "this is right"
WRONG = "this is wrong"

class A
  include RubySync::Utilities

  option :just_one
  option :pet, :just_default, :with_default
  just_default RIGHT
  with_default WRONG
end

class B < A
  pet RIGHT
  with_default RIGHT
  just_one RIGHT
end

class C < A
  pet WRONG
  with_default WRONG
  just_one WRONG
end


class TcUtilities < Test::Unit::TestCase

  def test_class_option
    b = B.new
    assert_equal RIGHT, b.pet
    assert_equal RIGHT, b.just_default
    assert_equal RIGHT, b.with_default
    assert_equal RIGHT, b.just_one
    c = C.new
    assert_equal WRONG, c.pet
    assert_equal RIGHT, c.just_default
    assert_equal WRONG, c.with_default
    assert_equal WRONG, c.just_one
  end
  
  
  def test_effective_operations
    a = A.new
    entry = {
      "sn" => "Fox",
      "givenName" => %w{Michael Andrew},
      "shows" => "Family Ties"
    }
    
    op = RubySync::Operation
    ops = [
      op.add("fans", ["Ritchie"]),
      op.add("shows", ["Scrubs", "Boston Legal"]),
      op.replace("givenName", %w{Michael J}),
      op.delete("movies","Bright Lights, Big City")
    ]
    
    e = a.effective_operations(ops, entry)
    
    assert_equal op.add("fans", ["Ritchie"]), e[0]
    assert_equal op.replace("shows", ["Scrubs", "Boston Legal"]), e[1]
    assert_equal op.replace("givenName", %w{Michael J}), e[2]
    assert_equal 3, e.size
  end


  def test_deep_diff_with_binary_data
    s1 = "���������������������"
    assert !Net::LDIF.base64_value?(s1)

    h1 = {:to => s1}
    h2 = {:to => Base64.encode64(s1)}
    h3 = {}
    assert_equal h3, h1.deep_diff(h2)

    h1 = {:to => s1}
    h2 = {:to => Base64.encode64(s1)}
    assert_equal h3, h2.deep_diff(h1)

    s2 = "F�D+
sJO�;��_Ci�
  ���������������������
F�D+
sJO�;��_Ci�
"
    assert !Net::LDIF.base64_value?(s2)

    h1 = {:to => s2}
    h2 = {:to => Base64.encode64(s2)}
    h3 = {}
    
    assert_equal h3, h1.deep_diff(h2)
    assert_equal h3, h2.deep_diff(h1)

    h1 = {:to => [s2]}
    h2 = {:to => [Base64.encode64(s2)]}
    h3 = {}
    assert_equal h3, h1.deep_diff(h2)
    assert_equal h3, h2.deep_diff(h1)

    h1 = {:to => [s2]}
    h2 = {:to => Base64.encode64(s2)}
    h3 = {}
    assert_equal h3, h1.deep_diff(h2)
    assert_equal h3, h2.deep_diff(h1)

    h1 = {:to => [s2]}
    h2 = {:to => [Base64.encode64(s2)]}
    h3 = {}
    assert_equal h3, h1.deep_diff(h2)
    assert_equal h3, h2.deep_diff(h1)

    s3 = "coco"
    h1 = {:ki => s3}.merge(h1)
    h2 = {:ki => [s3]}.merge(h2)
    h3 = {}
    assert_equal h3, h1.deep_diff(h2)
  end

  
end