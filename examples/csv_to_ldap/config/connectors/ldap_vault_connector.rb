class LdapVaultConnector < RubySync::Connectors::LdapConnector
  
  # ApacheDS config
  host          'localhost'
  port          10390
  username      'uid=admin,ou=system'
  password      'secret'
  #changelog_dn  'cn=changelog'
  search_filter "cn=*"
  search_base   "ou=users,ou=system"

  # OpenLDAP config
#  host          'localhost'
#  port          389
#  username      'cn=admin,dc=localhost'
#  password      'secret'
#  #changelog_dn  'cn=changelog'
#  search_filter 'cn=*'
#  search_base   'dc=localhost'

  # Default config
#   host           'localhost'
#   port            389
#   username       'cn=Manager,dc=my-domain,dc=com'
#   password       'secret'
#   search_filter  "cn=*"
#   search_base    "ou=users,o=my-organization,dc=my-domain,dc=com"
#   #:bind_method  :simple

end
