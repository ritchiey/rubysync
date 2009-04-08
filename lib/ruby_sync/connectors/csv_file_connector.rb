#!/usr/bin/env ruby
#
#  Created by Ritchie Young on 2007-01-29.
#  Copyright (c) 2007. All rights reserved.

require "csv"
require "ruby_sync/connectors/file_connector"

module RubySync::Connectors
  
    
    # Reads files containing Comma Separated Values from the in_path directory and
    # treats each line as an incoming event.
    #
    # This Connector can't act as an identity vault.
    class CsvFileConnector < RubySync::Connectors::FileConnector
      
      option  :field_names, # A list of names representing the namesspace for this connector
              :path_field, # The name of the field to use as the source_path
              :header_line # true if the first line is a header and should be ignored during imports
      
      in_glob       '*.csv'
      out_extension '.csv'
      field_names   []
      path_field((get_field_names.empty?)? 'field_0': @field_names[0])
      
      
      # Called for each filename matching in_glob in in_path
      # Yields an add event for each row found in the file.
      def each_file_change(filename)
        header = header_line
            
        fields = (self.respond_to? :field_names and field_names)? field_names : nil        
        CSV.open(filename, 'r') do |row|
          if header
            # If field names not specified, derive from the header
            fields ||=  row
            header = false
            next
          end

          if row.length > fields.length
            log.warn "#{name}: Row in file #{filename} exceeds defined field_names"
          end
          
          data = {}
          row.each_index do |i|
            field_name = (i < fields.length)? fields[i] : "field_#{i}"
            row[i] and data[field_name] = row[i].data
          end
          association_key = source_path = path_for(data)
          yield RubySync::Event.add(self, source_path, association_key, create_operations_for(data))
        end
      end

      def self.sample_config
          return <<END

            # True if the first line of each file is a header
            header_line   true
                                                             
            # If field_names not specified and header_line is true then,
            # the fields names will be derived from the first line in each CSV file
            field_names   ['names', 'of', 'the', 'columns']
            path_field    'name_of_field_to_use_as_the_id'
            in_path       '/directory/to/read/files/from'
            out_path      '/directory/to/write/files/to'
            in_glob       '*.csv'
            out_extension '.csv'
END
      end
            
      def self.fields
        c = self.new
        c.field_names and !c.field_names.empty? or
          log.warn "Please set the field names in the connector config."
        c.field_names || []
      end

      def write_record file, path, operations
        record = perform_operations operations
        line = CSV.generate_line(field_names.map {|f| record[f]})
        file.puts line
      end
        

      
      # Return the value to be used as the source_path for the event given the
      # supplied row data.
      def path_for(data)
        if defined? path_field
          return data[path_field]
        end
        return nil
      end
      
      # A file based system probably can't look data up so always return nil
      # for lookup attempts
      def [](path)
        nil
      end
      
      def delete(path)
        log.warn "Delete on CSV driver ignored for #{path}"
      end
      
    end
  end
