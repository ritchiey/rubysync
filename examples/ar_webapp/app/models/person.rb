class Person < ActiveRecord::Base

  has_many :association_keys, :as=>:synchronizable, :dependent=>:destroy
  has_many :interests
  has_many :hobbies, :through=>:interests

end
