class DatabankConnector < RubySync::Connectors::XmlConnector
  
#
# You would normally specify an absolute pathname here.
#
filename "#{File.dirname(__FILE__)}/../../databank.xml"
      
end
