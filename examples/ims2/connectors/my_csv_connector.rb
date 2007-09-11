class MyCsvConnector < RubySync::Connectors::CsvFileConnector
            options(
            :name=>"MyCSV",
            :field_names=>['given name', 'last name', 'phone number', 'email'],
            :path_field=>'email',
            :in_path=>'/tmp/csv/in',
            :out_path=>'/tmp/csv/out',
            :in_glob=>'*.csv',
            :out_extension=>'.csv'
          )

end
