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

require 'tc_csv_file_connector'
require 'tc_memory_connectors'
require 'tc_ldif'
require 'tc_base_pipeline'
#require 'test_ldap_connector'
#require 'test_active_record_connector'