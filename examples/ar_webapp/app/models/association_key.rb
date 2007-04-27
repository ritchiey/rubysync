class AssociationKey < ActiveRecord::Base

  belongs_to :person, :class_name => "Person", :foreign_key => "record_id"
end
