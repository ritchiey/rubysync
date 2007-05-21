class HrImportPipeline < RubySync::Pipelines::BasePipeline

  client :corp_directory
  vault :hr_db

  map_client_to_vault :givenname  => :first_name,
                      :sn         => :last_name
                      


  allow_out :first_name, :last_name
  allow_in :first_name, :last_name


  # in means going from client to vault
  #in_transform do
  #end

  # out means going from vault to client
  out_transform do
    add_default :cn, "Ritchie"
  end

  def out_place event
    #event.target_path = "blah"
    event.target_path = "cn=Ritchie,dc=example,dc=com"
  end
  
end
