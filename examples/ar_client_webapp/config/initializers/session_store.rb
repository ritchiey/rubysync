# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_ar_client_webapp_session',
  :secret      => '819250945b78be326aaa70f601a5bdb2c8ceed8071a326a842791ee8232e64a9b202aae054b595029c3680ecb505d604c216d4459d64619aad8aac1bb210b755'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
