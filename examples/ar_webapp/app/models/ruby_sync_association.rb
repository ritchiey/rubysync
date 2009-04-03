class RubySyncAssociation < ActiveRecord::Base
  belongs_to :synchronizable, :polymorphic => true
end
