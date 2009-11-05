class User < ActiveRecord::Base
  named_scope :all_username_begin_by, lambda{ |char| {:conditions => "username LIKE '#{char}%'"}}
end
