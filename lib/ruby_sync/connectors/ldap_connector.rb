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


lib_path = File.dirname(__FILE__) + '/..'
$:.unshift lib_path unless $:.include?(lib_path) || $:.include?(File.expand_path(lib_path))

require 'ruby_sync'
require 'net/ldap'


module RubySync
  module Connectors
    class LdapConnector < RubySync::Connectors::BaseConnector
      
      attr_accessor :host, :port, :bind_method, :username, :password
      
      def initialize options
        super options
        @bind_method ||= :simple
        @host ||= 'localhost'
        @port ||= 389
      end
      
      
      def add(path, operations)
          with_ldap {|ldap| ldap.add :dn=>path, :attributes=>perform_operations(operations)}
      end

      def modify(path, operations)
        with_ldap {|ldap| ldap.modify :dn=>path, :operations=>operations }
      end

      def delete(path)
        with_ldap {|ldap| ldap.delete :dn=>path }
      end

      def [](path)
        with_ldap do |ldap|
          result = ldap.search :base=>path, :scope=>Net::LDAP::SearchScope_BaseObject, :filter=>'objectclass=*'
          return nil if !result or result.size == 0
          return result[0]
        end
      end
      
      def target_transform event
        event.add_default 'objectclass', 'inetOrgUser'
      end

private
      def with_ldap
        result = nil
        Net::LDAP.open(:host=>@host, :port=>@port, :auth=>auth) do |ldap|
          result = yield ldap
        end
        result
      end
      
      def auth
        {:method=>@bind_method, :username=>@username, :password=>@password}
      end
    end
  end
end