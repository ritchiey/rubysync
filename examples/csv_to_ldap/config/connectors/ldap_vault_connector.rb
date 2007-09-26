class LdapVaultConnector < RubySync::Connectors::LdapConnector
        
   host           'localhost'
   port            389
   username       'cn=Manager,dc=my-domain,dc=com'
   password       'secret'
   search_filter  "cn=*"
   search_base    "ou=users,o=my-organization,dc=my-domain,dc=com"
   #:bind_method  :simple

end
