class HrImportPipeline < RubySync::Pipelines::BasePipeline

  client :hr

  vault :ldap_vault

  # Remove any fields that you don't want to set in the vault from the client
  allow_in 'id', 'first_name', 'last_name', 'skills'

  # "in" means going from client to vault
  in_transform do
    map 'cn', 'id'
    map 'sn', 'last_name'
    map 'givenname', 'first_name'
    map('employeeType') { value_of('skills').split(':') }
    drop_changes_to 'skills'
    map('objectclass') { 'inetOrgPerson' }
  end
  # Should evaluate to the path for placing a new record on the vault
  in_place do
    "cn=#{source_path},ou=users,o=my-organization,dc=my-domain,dc=com"
  end

end
