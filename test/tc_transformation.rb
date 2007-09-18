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
# Tests transformation operations in the Event class
#
[File.dirname(__FILE__) + '/../lib', File.dirname(__FILE__)].each do |lib_path|
  $:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))
end
require 'ruby_sync_test'
require 'ruby_sync/connectors/xml_connector'


class TransformationVaultConnector < RubySync::Connectors::MemoryConnector
  dbm_path "/tmp/rubysync_xml"
end

class TransformationClientConnector < RubySync::Connectors::MemoryConnector
  dbm_path "/tmp/rubysync_memory"
end


class TransformationTestPipeline < RubySync::Pipelines::BasePipeline
  client :transformation_vault
  vault :transformation_client
  
  in_transform do
   map :first_name, :givenName
   map :last_name, :sn
   # Calculated value
   map(:hobbies) {values_for(:interests).join ':'}
   # Constant string
   map(:note) {"Created by RubySync"}
   map(:shopping) {%w/fish milk bread/}
  end
end

class TcTransformation < Test::Unit::TestCase
  
  include RubySyncTest

  def client_path() 'bob'; end
  def vault_path() 'bob'; end
  
  def testPipeline
    TransformationTestPipeline
  end
  
  def test_transform
    @client['bob'] = @bob_details
    @pipeline.run_once
    assert_equal @bob_details['givenName'], @vault['bob']['first_name']
    assert_equal @bob_details['sn'], @vault['bob']['last_name']
    assert_equal "Created by RubySync", @vault['bob']['note'][0]
    assert_equal "music:makeup", @vault['bob']['hobbies'][0]
    assert_equal %w/fish milk bread/, @vault['bob']['shopping']
  end
  
end
