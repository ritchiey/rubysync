class AssociationKey < ActiveRecord::Base

  belongs_to :synchronizable, :polymorphic=>true

end
