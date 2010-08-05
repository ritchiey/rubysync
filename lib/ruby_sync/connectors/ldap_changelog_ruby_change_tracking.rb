# Copyright (c) 2010 Nowhere Man. All rights reserved.
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

require 'ruby_sync/connectors/ldap_changelog_ruby_connector'

module RubySync::Connectors

  module LdapChangelogRubyChangeTracking
    include LdapChangelogNumberTracking
    include LdapChangelogRubyChange
    include LdapChangelogEventProcessing
#    include LdapAssociationTracking

    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def acts_as_change_tracking
        send :include, InstanceMethods
      end
    end

    module InstanceMethods

      def started
        # TODO: If vault, check the schema to make sure that the association_attribute is there
        @ldap_connections = []
        @ldap_connection_index = 0
                
        super
      end

      # Set in case one of the ldap tracking modules is used.
      def with_ldap( connector = nil)
#        if is_a?(RubySync::Connectors::LdapConnector)
        if connector #&& is_a?(RubySync::Connectors::LdapConnector)
          super
        else
          result = nil


          track_changes_attributes = {}
          attributes = [:ldap_path_field, :ldap_host, :ldap_bind_method, :ldap_port,
            :ldap_username, :ldap_password, :ldap_search_filter]

          attributes.each do |attribute|
            connector_attribute = attribute.to_s.gsub(/^ldap_(.+)$/,'\1')
            if !respond_to?(attribute) && respond_to?(connector_attribute)
              track_changes_attributes[attribute] = send(connector_attribute)
            end
          end
          
          self.class.track_option *attributes
          track_changes_attributes.each do |key, value|
            if self.class.respond_to?("#{key}=")
              self.class.send("#{key}=", value)
            else
              log.debug "#{name}: doesn't respond to #{key}="
            end
          end

          auth= { :method => ldap_bind_method, :username => ldap_username, :password => ldap_password }
          connection_options = { :host => ldap_host, :port => ldap_port, :auth => auth }
          connection_options[:encryption] = ldap_encryption if respond_to?(:ldap_encryption) && ldap_encryption
          started unless @ldap_connection_index

          @ldap_connections[@ldap_connection_index] = Net::LDAP.new(connection_options) unless @ldap_connections[@ldap_connection_index]
          if @ldap_connections[@ldap_connection_index]
            ldap = @ldap_connections[@ldap_connection_index]
            @ldap_connection_index += 1
            result = yield ldap
            @ldap_connection_index -= 1
          end
          result
        end

      end

    end

  end
  
end

#RubySync::Connectors::BaseConnector.send :include, RubySync::Connectors::LdapChangelogRubyChangeTracking