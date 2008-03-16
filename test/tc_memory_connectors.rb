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

#
# Performs end-to-end tests of the memory based testing connectors.
#
lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift lib_path unless $:.include?(lib_path)

require 'ruby_sync_test'
require 'hashlike_tests'
require 'ruby_sync/connectors/memory_connector'


class MemoryTestAConnector < RubySync::Connectors::MemoryConnector
end

class MemoryTestBConnector < RubySync::Connectors::MemoryConnector
end

class MemoryTestPipeline < RubySync::Pipelines::BasePipeline
  client :memory_test_a
  vault :memory_test_b
  allow_in
  allow_out
end

class TcMemoryConnectors < Test::Unit::TestCase
  
  include RubySyncTest
  include HashlikeTests

  def testPipeline
    MemoryTestPipeline
  end
  
end
