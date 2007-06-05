class MyCsvConnector < RubySync::Connectors::CsvFileConnector
            
            field_names   ['id', 'given_name', 'surname']
            path_field    :id
            in_path       '/tmp/rubysync/in'
            out_path      '/tmp/rubysync/out'
            in_glob       '*.csv'
            out_extension '.csv'

end
