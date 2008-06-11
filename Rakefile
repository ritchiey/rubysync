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

require 'rubygems'
require 'hoe'
require './lib/ruby_sync.rb'

Hoe.new('rubysync', RubySync::VERSION) do |p|
  p.rubyforge_name = 'rubysync'
  p.author = 'Ritchie Young'
  p.email = 'ritchiey@gmail.com'
  p.summary = "Event driven identity synchronization engine"
  p.description = p.paragraphs_of('README.txt', 1..5).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.remote_rdoc_dir = ""
  p.extra_deps = [
    ["ruby-net-ldap", ">=0.0.4"],
    ["activesupport", ">=1.4.0"],
    ["activerecord", ">=1.15.3"],
    ["simpleconsole", ">=0.1.1"],
    ["contacts", ">=1.0.7"]
    ]
end
