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
require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'
require 'spec/rake/spectask'
require 'lib/ruby_sync.rb'

spec = Gem::Specification.new do |s|
  s.name = 'rubysync'
  s.version = RubySync::VERSION
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.txt', 'COPYING']
  s.summary = 'Event driven identity synchronization engine'
  s.description = s.summary
  s.homepage = 'http://rubysync.org/'
  s.rubyforge_project = 'rubysync'
  s.author = 'Ritchie Young'
  s.email = 'ritchiey@gmail.com'
  # s.executables = ['your_executable_here']
  s.files = %w(COPYING README.txt Rakefile) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
  s.add_dependency('my-ruby-net-ldap', '>=0.5.0')
  s.add_dependency('activesupport', '<3.0.0')
  s.add_dependency('activerecord', '<3.0.0')
  s.add_dependency('sqlite3-ruby', '<1.3.0')
  s.add_dependency('simpleconsole', '>=0.1.1')
  s.add_dependency('contacts', '>=1.0.7')

end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

Rake::RDocTask.new do |rdoc|
  files =['README.txt', 'COPYING', 'lib/**/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = "README.txt" # page to start on
  rdoc.title = "RubySync Docs"
  rdoc.rdoc_dir = 'doc/rdoc' # rdoc output folder
  rdoc.options << '--line-numbers'
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*.rb']
end

Rake::TestTask.new do |t|
  t.name ='test:units'
  t.test_files = FileList['test/ts_rubysync.rb']
end

Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*.rb']
end

