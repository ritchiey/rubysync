class HrConnector < RubySync::Connectors::CsvFileConnector
  
            # True if the first line of each file is a header
            # and should be ignored
            header_line   true

            field_names   'id,first_name,last_name,skills'.split(',')
            path_field    'id'
            in_path       "#{File.dirname(__FILE__)}/../../in"
            #out_path      '/directory/to/write/files/to'
            in_glob       '*.csv'
            out_extension '.csv'

end
