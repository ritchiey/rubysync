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


require 'ruby_sync/util/utilities'
require 'test/unit'


module RubySync
  module Connectors
    autoload_dir "#{File.dirname(__FILE__)}/../lib", 'ruby_sync/connectors'
  end
end
autoload_dir "#{File.dirname(__FILE__)}/connectors"

class TcLoader < Test::Unit::TestCase

  def test_autoload_dir
    lib_path = File.dirname(__FILE__) + '/../lib'
    base_path = "#{lib_path}/ruby_sync/connectors"
    base_module = RubySync::Connectors
    assert_equal "#{base_path}/base_connector.rb", base_module.send(:autoload?,:BaseConnector)
    assert_equal "#{base_path}/xml_connector.rb", base_module.send(:autoload?, :XmlConnector)
    assert_equal "#{base_path}/csv_file_connector.rb", base_module.send(:autoload?,:CsvFileConnector)
    assert_equal "#{File.dirname(__FILE__)}/connectors/hr_connector.rb", autoload?(:HrConnector)
  end
  
end