class Person < ActiveRecord::Base
  
  has_many :association_keys, :class_name => "AssociationKey", :foreign_key => "record_id"
  has_many :interests
  has_many :hobbies, :through=>:interests
end
