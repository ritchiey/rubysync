class HrDbConnector < RubySync::Connectors::ActiveRecordConnector
  name        "HR Database",
  application "#{File.dirname(__FILE__)}/../../ar_webapp",
  model       :person

end
