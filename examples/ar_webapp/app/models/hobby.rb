class Hobby < ActiveRecord::Base
  
  has_many :interests
  has_many :people, :through=>:interests
end
