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

class TestConnector <  RubySync::Connectors::XmlConnector
  filename "/tmp/rubysync_test.xml"
end

class TestPipeline < RubySync::Pipelines::BasePipeline
  client :test_a
  vault :test_b
end

class TcXmlConnectors < Test::Unit::TestCase
  
  include RubySyncTest
  include HashlikeTests

  def secondary_setup
    @tc = TestConnector.new
    File.delete_if_exists [@client.filename, @vault.filename, @tc.filename]
  end
  
  
  
  #  def test_with_xml()
  #    File.delete(@client.filename)   
  #      mrA = {
  #        'sn' => "A",
  #        'givenName' => 'Mr'
  #      }
  #    @client.with_xml do |content|
  #      assert_equal({}, content)
  #      content['a'] = mrA
  #    end
  #    @client.with_xml do |content|
  #      assert_equal(mrA, content['a'])
  #    end
  #  end

  
  def test_xml_delete
    xml_test_document
    assert_not_nil @tc['tcd']
    assert_equal 'Dummy',@tc["tcd"]['sn']
    @tc.delete "tcd"
    assert_nil @tc['tcd']
  end
  
  def test_to_xml
    entry = {
      'sn'=>['Smith'],
      'givenName'=>%w/Bobby Earl/
    }
    
    xml = @tc.to_xml('bob', entry)
    doc = REXML::Document.new()
    doc << xml
    assert_equal doc, xml.document
    values = []
    xml.each_element("attr[@name='sn']/value") {|e| values << e.text}
    assert_equal entry['sn'].as_array, values
    values = []
    xml.each_element("attr[@name='givenName']/value") {|e| values << e.text}
    assert_equal entry['givenName'], values
    assert_equal entry, @tc.to_entry(xml)
  end
  
  def xml_test_document
    File.open(@tc.filename, "w") do |f|
      f.write <<END
<?xml version="1.0"?>
<entries>
  <entry id="ritchie">
    <attr name="sn">
      <value>Young</value>
    </attr>
    <attr name="givenName">
      <value>Ritchie</value>
    </attr>
    <attr name="hobbies">
      <value>Juggling</value>
      <value>Running</value>
      <value>Skipping</value>
    </attr>
  </entry>
  <entry id="ctd">
    <attr name="sn">
      <value>Dummy</value>
    </attr>
    <attr name="givenName">
      <value>Crash</value>
      <value>Test</value>
    </attr>
    <attr name="hobbies">
      <value>Falling</value>
      <value>Crashing</value>
      <value>Burning</value>
    </attr>
  </entry>
</entries>
END
    end
  end
end
