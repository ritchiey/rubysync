#!/usr/bin/env ruby
#
#  Created by Ritchie Young on 2007-01-29.
#  Copyright (c) 2007. All rights reserved.

require 'fileutils'

module RubySync
  
  module Connectors
    
    # An abstract class that serves as the base for connectors
    # that poll a filesystem directory for files and process them
    # and/or write received events to a file.
    class FileConnector < RubySync::Connectors::BaseConnector
      
      option  :in_path,  # scan this directory for suitable files
              :out_path, # write received events to this directory
              :out_extension, # the file extension of files written to out_path
              :in_glob # The filename glob for incoming files
      
      out_extension     ".out"
      
      def started
        ensure_dir_exists in_path
        ensure_dir_exists out_path
      end
      
      def each_change(&blk)
        unless in_glob
          log.error "in_glob not set on file connector. No files will be processed"
          return
        end
        log.info "#{name}: Scanning #{in_path} for #{in_glob} files..."
        Dir.chdir(in_path) do |path|
          Dir.glob(in_glob) do |filename|
            log.info "#{name}: Processing '#{filename}'"
            each_file_change filename, &blk
            FileUtils.mv filename, "#{filename}.bak"
          end
        end
      end
      
      # Called for each filename matching in_glob in in_path
      def each_file_change(filename,&blk)
      end


      # TODO: Write to a temp file first and then move it to where it will
      # be picked up by the receiving process.
      # TODO: Make this use the same file for multiple records depending
      # upon configuration of maximum lines per file and a timeout
      def add path, operations
        File.open(output_file_name, 'a') do |file|
          write_record(file, path, operations)
        end
        return true
      end

      # Called to append a given record to an open file.
      # Subclasses of FileConnector should override this.
      def write_record file, path, operations
        raise Exception.new("#{name} needs to implement 'write_record file, path, operations'")
      end
      
      
      # Generate a unique and appropriate filename within the given path 
      def output_file_name
       File.join(out_path, Time.now.strftime('%Y%m%d%H%M%S') + out_extension)
      end
            
    end
  end
end
