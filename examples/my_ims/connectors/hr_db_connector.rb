class HrDbConnector < RubySync::Connectors::ActiveRecordConnector
  
  options(
    :application => "#{File.dirname(__FILE__)}/../../ar_webapp",
    :model => :person
  )
end
