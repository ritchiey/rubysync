class FinanceConnector < RubySync::Connectors::ActiveRecordConnector
  options(
    :application => "#{File.dirname(__FILE__)}/../../ar_client_webapp",
    :model => :user
  )

end
