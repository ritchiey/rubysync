class FinancePipeline < RubySync::Pipelines::BasePipeline

  client :finance

  vault :hr_db

  # Remove any fields that you don't want to set in the client from the vault
  allow_out :first_name

  # Remove any fields that you don't want to set in the vault from the client
  allow_in :first_name, :last_name

  # If the client and vault have different names for the same field, define the
  # the mapping here. For example, if the vault has a field called "first name" and
  # the client has a field called givenName you may put:
  #    'first name' => 'givenName'
  # separate each mapping with a comma.
  # The following fields were detected on the client:
  # 'username', 'name', 'email'
  map_vault_to_client(
    'first_name' => 'name'
		#'last_name' => 'a_client_field'
  )

  # in means going from client to vault
  #in_transform do
  #end

  # out means going from vault to client
  #out_transform do
  #end

end
