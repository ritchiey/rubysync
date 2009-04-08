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

lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift lib_path unless $:.include?(lib_path)

require 'ruby_sync_test'
require 'ruby_sync/connectors/file_connector'
require 'ruby_sync/connectors/csv_file_connector'
require 'ruby_sync/connectors/memory_connector'
require 'csv'


class TestCsvFileConnector < RubySync::Connectors::CsvFileConnector
#  dbm_path "/tmp/rubysync_csv"  
  field_names ['id', 'given name', 'last name', 'email']
  path_field  'id'
  in_path     File.expand_path("~/rubysync/csv_test/in")
  out_path    File.expand_path("~/rubysync/csv_test/out")
  header_line false
end

class TestMemoryConnector < RubySync::Connectors::MemoryConnector
#  dbm_path "/tmp/rubysync_memory"  
end


class CsvTestPipeline < RubySync::Pipelines::BasePipeline
  client :test_csv_file
         
  vault :test_memory
  allow_in
  allow_out
  
  in_event_transform do
    map :cn, :id
    map :givenName, 'given name'
    map :sn, 'last name'
    map :mail, :email
  end   
    
end

class TcCsvConnector < Test::Unit::TestCase
  
  include RubySyncTest
    
  def setup
    @pipeline = CsvTestPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault
    @filename = "#{@client.in_path}/client_to_vault.csv"
    File.delete @filename if File.exists? @filename
    @pipeline.run_once # create the in and out directories if necessary
    @bob_details = {:cn=>'bob', :givenName=>"Robert", :sn=>"Smith", :mail=>'bob@thecure.com'}
    @headers = {:cn=>'id', :givenName=>'given name', :sn=>'last name', :mail=>'email'}
  end

  
#  def testPipeline
#    CsvTestPipeline
#  end
  
  def client_to_vault_with
    banner :test_client_to_vault
    CSV.open(@filename, 'w') { |csv| yield csv }
    assert_nil @vault["bob"], "Vault already contains bob"
    @pipeline.run_once
    assert_not_nil @vault["bob"], "Bob wasn't created in vault"
    modded_bob={}; @bob_details.each_pair {|k,v| modded_bob[k.to_s]=as_array(v)}
    assert_equal modded_bob, @vault["bob"].reject {|k,v| ['modifier',:association].include? k}
    @pipeline.run_once
  end
     
  def test_client_to_vault_no_header
    client_to_vault_with do |csv|
      record = [:cn, :givenName, :sn, :mail].map {|key| @bob_details[key]}     
      csv << record
    end
  end
  
  def test_client_to_vault_with_header
    # When there's a header and field_names aren't specified,
    # it should derive the field names from the header
    def @client.header_line() true; end
    def @client.field_names() nil; end

    client_to_vault_with do |csv|   
      keys = [ :givenName, :mail, :cn, :sn ]
      csv << keys.map { |key| @headers[key] }
      csv << keys.map { |key| @bob_details[key] }
    end
  end


end