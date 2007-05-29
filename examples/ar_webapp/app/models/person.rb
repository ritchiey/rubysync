class Person < ActiveRecord::Base

  has_many :ruby_sync_associations, :as=>:synchronizable, :dependent=>:destroy
  has_many :interests
  has_many :hobbies, :through=>:interests



end
