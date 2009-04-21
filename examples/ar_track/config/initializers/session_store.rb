# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_ar_mirror_session',
  :secret      => '4748ba9788af96ba3daa4bb79558c44619389e78f9bcb3d2a7f73c20371e5c9ac9940a76b1ba3cc32ef2d5a880a756defbb9fc936335943e46338566d1e9541a'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
