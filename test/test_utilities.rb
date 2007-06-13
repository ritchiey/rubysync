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


class TestUtilities < Test::Unit::TestCase

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
  
end