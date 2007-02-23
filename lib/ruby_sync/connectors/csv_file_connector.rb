#!/usr/bin/env ruby
#
#  Created by Ritchie Young on 2007-01-29.
#  Copyright (c) 2007. All rights reserved.

require "csv"
require "ruby_sync/connectors/file_connector"

module RubySync
  
  module Connectors
    
    # Reads files containing Comma Separated Values from the in_path directory and
    # treats each line as an incoming event.
    #
    # This Connector can't act as an identity vault.
    class CsvFileConnector < RubySync::Connectors::FileConnector
      
      attr_accessor :field_names # A list of names representing the namesspace for this connector
      attr_accessor :path_field # The name of the field to use as the source_path
      

      def initialize options
        super options
        @in_glob ||= "*.csv"
        @field_names ||= []
        @path_field ||= (@field_names.empty?)? "field_0": @field_names[0]
      end
      
      # Called for each filename matching in_glob in in_path
      # Yields a modify event for each row found in the file.
      def check_file(filename)
        CSV.open(filename, 'r') do |row|
          if defined? field_name &&row.length > field_names.length
            log.warn "#{name}: Row in file #{filename} exceeds defined field_names"
          end
          
          data = {}
          row.each_index do |i|
            field_name = (i < field_names.length)? field_names[i] : "field_#{i}"
            data[field_name] = row[i].data
          end
          source_path = path_for(data)
          association_key = (is_vault?)? nil : association_key_for(data[path_field])
          yield RubySync::Event.modify(self, source_path, association_key, create_operations_for(data))
        end
      end

      
      # Return the value to be used as the source_path for the event given the
      # supplied row data.
      def path_for(data)
        if defined? @path_field
          return data[@path_field]
        end
        return nil
      end
      
    end
  end
end
