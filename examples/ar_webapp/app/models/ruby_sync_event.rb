class RubySyncEvent < ActiveRecord::Base
  
  #belongs_to :trackable, :polymorphic=>true
  
  has_many :operations,
          :class_name => "RubySyncOperation",
          :foreign_key => "ruby_sync_event_id"
  
end
