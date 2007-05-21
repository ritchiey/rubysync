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

require 'ruby_sync'
require 'test/unit'

module RubySyncTest


  def initialize(test)
    super(test)
    @bob_details = {:givenName=>['Robert'],
                    :sn=>['Smith'],
                    :interests=>['music', 'makeup']
    }
  end
  

  def setup
    @pipeline = TestPipeline.new
    @client = @pipeline.client
    @vault = @pipeline.vault
    @client.delete(client_path) if @client[client_path]
    @vault.delete(vault_path) if @vault[vault_path]
  end  

  def banner(label)
    puts '*' * 10 + " #{label} " + '*' * 10
  end
  
end