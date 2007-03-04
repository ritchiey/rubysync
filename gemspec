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


require 'rubygems'

SPEC = Gem::Specifications.new do |s|
  s.name = "RubySync"
  s.version = "0.0.1"
  s.author = "Ritchie Young"
  s.email = "ritchiey@gmail.com"
  s.homepage = "http://rubysync.org"
  s.platform = "Gem::Platform::RUBY"
  s.summary = "Event driven identity synchronization"
  candidates = Dir.glob "{bin,docs,lib,test}/**/*"
  s.files = candidates.delete_if do |item|
    item.include?("rubysync.tmproj") ||
    item.include?(".svn") ||
    item.include?(".project") ||
    item.include?('.DS_Store')
  end
  s.require_path = 'lib'
  s.autorequire = 'rubysync'
  s.test_file = 'test/ts_rubysync.rb'
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency "ruby-net-ldap", ">=0.0.4"
  s.add_dependency "activesupport", ">=1.4.0"
  s.add_dependency "simpleconsole", ">=0.1.1"
end