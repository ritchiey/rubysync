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

lib_path = File.dirname(__FILE__) + '/../lib'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync_test'
require 'ruby_sync/connectors/csv_file_connector'
require 'ruby_sync/connectors/memory_connector'
require 'csv'


class TestCsvFileConnector < RubySync::Connectors::CsvFileConnector
  dbm_path "/tmp/rubysync_csv"  
  field_names ['id', 'given name', 'last name', 'email']
  path_field  'id'
  in_path     File.expand_path("~/rubysync/csv_test/in")
  out_path    File.expand_path("~/rubysync/csv_test/out")
  header_line false
end

class TestMemoryConnector < RubySync::Connectors::MemoryConnector
  dbm_path "/tmp/rubysync_memory"  
end


class TestPipeline < RubySync::Pipelines::BasePipeline
  client :test_csv_file
         
  vault :test_memory
  
  map_client_to_vault 'id'=>:cn,
                      'given name'=>:givenName,
                      'last name'=>:sn,
                      "email"=>:mail
  
end

class TcCsvConnector < Test::Unit::TestCase
  
  include RubySyncTest
    
  def setup
    @pipeline = TestPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault
    @filename = "#{@client.in_path}/client_to_vault.csv"
    File.delete @filename if File.exists? @filename
    @pipeline.run_once # create the in and out directories if necessary
    @bob_details = {:cn=>'bob', :givenName=>"Robert", :sn=>"Smith", :mail=>'bob@thecure.com'}
  end

  def test_client_to_vault
    banner :test_client_to_vault
    CSV.open(@filename, 'w') do |csv|
      csv << [:cn, :givenName, :sn, :mail].collect {|key| @bob_details[key]}
    end
    assert_nil @vault["bob"], "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil @vault["bob"], "Bob wasn't created in vault"
    modded_bob={}; @bob_details.each_pair {|k,v| modded_bob[k.to_s]=as_array(v)}
    assert_equal modded_bob, @vault["bob"].reject {|k,v| ['modifier',:association].include? k}
    @pipeline.run_once
  end

end