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
      
      attr_accessor :in_path  # scan this directory for suitable files
      attr_accessor :out_path # write received events to this directory
      attr_accessor :in_glob # The filename glob for incoming files
      
      
      def started
        ensure_dir @in_path
        ensure_dir @out_path
      end
      
      def check(&blk)
        unless in_glob
          log.error "in_glob not set on file connector. No files will be processed"
          return
        end
        log.info "#{name}: Scanning #{in_path} for #{in_glob} files..."
        Dir.chdir(in_path) do |path|
          Dir.glob(in_glob) do |filename|
            log.info "#{name}: Processing '#{filename}'"
            check_file filename, &blk
            FileUtils.mv filename, "#{filename}.bak"
          end
        end
      end
      
      # Called for each filename matching in_glob in in_path
      def check_file(filename,&blk)
      end


      def ensure_dir path
        raise Exception.new("Can't create nil directory") unless path
        if File.exist? path
          unless File.directory? path
            raise Exception.new("'#{path}' exists but is not a directory")
          end
        else
          log.info "Creating directory '#{path}'"
          FileUtils.mkpath path
        end
      end
      
    end


  end
end
