class HrImportPipeline < RubySync::Pipelines::BasePipeline

  client :corp_directory

  vault :hr_db

  map_client_to_vault :givenName  => :first_name,
                      :sn         => :last_name

  allow_out :first_name, :last_name
  allow_in :first_name, :last_name


  # in means going from client to vault
  #in_transform do
  #end

  # out means going from vault to client
  #out_transform do
  #end

end
