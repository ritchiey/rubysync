class CorpDirectoryConnector < RubySync::Connectors::LdapConnector
 
 options(
   :host=>'localhost',
   :port=>10389,
   :username=>'uid=admin,ou=system',
   :password=>'secret',
   :search_filter=>"cn=*",
   :search_base=>"dc=example,dc=com"
  )
  
end
