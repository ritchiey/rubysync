class User < ActiveRecord::Base
  named_scope :username_begin_by, lambda{ |char| {:conditions => "username LIKE '#{char}%'"}}
end
