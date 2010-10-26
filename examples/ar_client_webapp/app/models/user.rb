class User < ActiveRecord::Base
  validates_uniqueness_of :username
  named_scope :username_begin_by, lambda { |char| {:conditions => "username LIKE '#{char}%'"} }
end
