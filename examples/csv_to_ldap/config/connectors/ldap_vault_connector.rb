class LdapVaultConnector < RubySync::Connectors::LdapConnector 
  
   track_changes_with :dbm
   track_associations_with :dbm
        
   host           'localhost'
   port            10389
   username       'cn=Manager,dc=my-domain,dc=com'
   password       'secret'
   search_filter  "cn=*"
   search_base    "ou=users,o=my-organization,dc=my-domain,dc=com"
   #:bind_method  :simple

end
