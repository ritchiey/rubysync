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

class TestEvent < Test::Unit::TestCase
  
  def setup
    payload = [
      RubySync::Operation.add("name", "Matthew"),
      RubySync::Operation.add(:modifier, "rubysync")
    ]
    @connector = RubySync::Connectors::MemoryConnector.new :name=>"Test"
    @event = RubySync::Event.modify @connector, 'source_path', nil, payload
    puts @event.to_yaml
  end

  def test_sets_value?
    assert @event.sets_value?(:modifier, "rubysync")
    assert !@event.sets_value?(:modifier, "Matthew")
  end

end