class LdapVaultConnector < RubySync::Connectors::LdapConnector 
  
   track_changes_with :dbm
   track_associations_with :dbm
        
   host           'localhost'
   port            10389
   username       'uid=admin,ou=system'
   password       'secret'
   search_filter  "cn=*"
   search_base    "dc=example,dc=com"
   #:bind_method  :simple

end
