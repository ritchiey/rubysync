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


require 'net/ldif'
require 'test/unit'

# TODO: Work out a cross platform method for testing file:// URL imports
class TcLDIF < Test::Unit::TestCase
  
  def setup
    @ldif = Net::LDIF    
  end
  
  def test_tokenizer
    a = array_for_file "example1.ldif"
    #a.each_index {|i| puts "#{i}\t#{a[i][0]}:#{a[i][1]}"}
    assert_equal ["version", "1"], a[0]
    assert_equal ["dn", "cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com"],a[1]
    assert_equal [nil,nil], a[12], "Blank line didn't yield nil name"
    assert_equal ["telephonenumber", "+1 408 555 1212"], a[19]

    a = array_for_file "example2.ldif"
    assert_equal ["description", "Babs is a big sailing fan, and travels extensively in search of perfect sailing conditions."],a[11]
    assert_equal ["title", "Product Manager, Rod and Reel Division"],a[12]
  end

  def test_tokenize_base64
    a = array_for_file "example3.ldif"
    #a.each_index {|i| puts "#{i}\t#{a[i][0]}:#{a[i][1]}"}
    assert_equal ["description", "What a careful reader you are!  This value is"+
      " base-64-encoded because it has a control character in it (a CR).\r"+
      "  By the way, you should really get out more."], a[10]
  end


  def test_tokenize_hyphens
    a = array_for_file "example6.ldif"
    #a.each_index {|i| puts "#{i}\t#{a[i][0]}:#{a[i][1]}"}
    assert_equal ["telephonenumber","+1 408 555 1212"], a[9]
    [30,33,37,40,45,47].each {|i| assert_equal ["-","-"], a[i]}
    
  end
  
  def test_parse_simple_content
    c = changes_for("example1.ldif")
    assert_equal 2, c.length
    assert_equal 'add', c[0].changetype
    assert_equal 'cn=Barbara Jensen, ou=Product Development, dc=airius, dc=com', c[0].dn
    assert_equal ['top','person','organizationalPerson'], c[0].data['objectclass']
    assert_equal ['Barbara Jensen','Barbara J Jensen','Babs Jensen'], c[0].data['cn']
    assert_equal 'Jensen', c[0].data['sn']
    assert_equal 'A big sailing fan.', c[0].data['description']
    
    assert_equal 'add', c[1].changetype
    assert_equal "cn=Bjorn Jensen, ou=Accounting, dc=airius, dc=com", c[1].dn
    assert_equal '+1 408 555 1212', c[1].data['telephonenumber']
  end

  def test_parse_change_records
    c = changes_for("example6.ldif")
    assert_equal 6, c.length
    #puts c.join("\n---\n")
    assert_equal "cn=Fiona Jensen, ou=Marketing, dc=airius, dc=com", c[0].dn
    assert_equal 'add', c[0].changetype
    assert_equal ['top', 'person', 'organizationalPerson'], c[0].data['objectclass']

    assert_equal "Fiona Jensen", c[0].data['cn']
    assert_equal "+1 408 555 1212", c[0].data['telephonenumber']
    
  end

private

  def changes_for(filename)
    content = []
    with_file(filename) do |file|
      @ldif.parse(file) do |record|
        assert_kind_of Net::ChangeRecord, record
        content << record
      end
    end
    content
  end


  def array_for_file filename
    array = []
    tokenize_file(filename) {|name, value| array << [name, value]}
    array    
  end

  def tokenize_file filename
    with_file(filename) do |file|
      @ldif.tokenize(file) { |name, value| yield name,value }
    end
  end

  def with_file(filename)
    File.open(path_for(filename), 'r') {|file| yield file}
  end

  def path_for filename
    "#{File.dirname(__FILE__)}/data/#{filename}"
  end
  
end
