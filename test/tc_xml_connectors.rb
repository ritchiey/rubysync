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
[File.dirname(__FILE__) + '/../lib', File.dirname(__FILE__)].each do |lib_path|
  $:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))
end
require 'ruby_sync_test'
require 'hashlike_tests'
require 'ruby_sync/connectors/xml_connector'


class TestAConnector < RubySync::Connectors::XmlConnector
  dbm_path "/tmp/rubysync_a"
  filename "/tmp/rubysync_a.xml"
end

class TestBConnector < RubySync::Connectors::XmlConnector
  dbm_path "/tmp/rubysync_b"
  filename "/tmp/rubysync_b.xml"
end

class TestPipeline < RubySync::Pipelines::BasePipeline
  client :test_a
  vault :test_b
end

class TcXmlConnectors < Test::Unit::TestCase
  
  include RubySyncTest
  include HashlikeTests

end
