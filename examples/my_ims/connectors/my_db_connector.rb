class MyDbConnector < RubySync::Connectors::ActiveRecordConnector
  
    application "#{File.dirname(__FILE__)}/../../ar_webapp"
    model 'person'


end
