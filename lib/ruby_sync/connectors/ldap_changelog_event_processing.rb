#!/usr/bin/env ruby
#
#  Copyright (c) 2009 Nowhere Man
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


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

#$VERBOSE = false
#require 'net/ldap'
#$VERBOSE = true

module RubySync::Connectors
  module LdapChangelogEventProcessing
    private

    def event_for_changelog_entry cle
      payload = nil
      if cle.respond_to?(:targetdn) && !cle.targetdn.blank?
        path = dn = cle.targetdn[0]
      elsif RUBYSYNC_SOURCE_INFO_ATTRIBUTE && !cle.send(RUBYSYNC_SOURCE_INFO_ATTRIBUTE).blank? && !cle.dn.blank?
        path = cle.send(RUBYSYNC_SOURCE_INFO_ATTRIBUTE)[0]
        dn = cle.dn
      else
        raise Exception.new("No DN in this ChangeLog Entry")
      end
   
      changetype = cle.changetype[0]
      if cle.attribute_names.include? :changes
        payload = []
        cr = Net::LDIF.parse("dn: #{dn}\nchangetype: #{changetype}\n#{cle.changes[0]}")[0]
        if changetype.to_sym == :add
          # cr.data will be a hash of arrays or strings (attr-name=>[value1, value2, ...])
          cr.data.each do |name, values|
            payload << RubySync::Operation.add(name.underscore, values)
          end
        else
          # cr.data will be an array of arrays of form [:action, :subject, [values]]
          cr.data.each do |record|
            payload << RubySync::Operation.new(record[0], record[1].underscore, record[2])
          end
        end
      end
      RubySync::Event.new(changetype, self, path, nil, payload)
    end

  end
end
