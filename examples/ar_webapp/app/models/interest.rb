class Interest < ActiveRecord::Base
  
  belongs_to :hobby
  belongs_to :person
  
end
