class LdapVaultConnector < RubySync::Connectors::LdapConnector
  
  track_changes_with :dbm
  track_associations_with :dbm  

  # ApacheDS config
  host          'localhost'
  port          10389
  username      'uid=admin,ou=system'
  password      'secret'
  search_filter "cn=*"
  search_base   "ou=users,ou=system"
  #:bind_method  :simple

  # OpenLDAP config
#  host          'localhost'
#  port          389
#  username      'cn=admin,dc=localhost'
#  password      'secret'
#  search_filter 'cn=*'
#  search_base   'dc=localhost'
#  #:bind_method  :simple

end