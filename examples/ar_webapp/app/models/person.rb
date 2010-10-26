class Person < ActiveRecord::Base

  has_many :ruby_sync_associations, :as => :synchronizable, :dependent => :destroy, :primary_key => :first_name
  has_many :interests
  has_many :hobbies, :through=>:interests

  validates_uniqueness_of :first_name

end
