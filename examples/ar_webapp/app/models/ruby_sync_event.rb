class RubySyncEvent < ActiveRecord::Base
  
  # This association doesn't work, :primary_key isn't used and 'trackable_id' must be a string
#  belongs_to :trackable, :primary_key => 'code', :polymorphic => true

  # Alternative method
  def trackable
    trackable_type.constantize.first(:conditions => { :code => trackable_id } )
  end
  
  belongs_to :state, :class_name => 'RubySyncState', :foreign_key => 'ruby_sync_state_id'

  has_many :operations,
          :class_name => "RubySyncOperation",
          :foreign_key => "ruby_sync_event_id"
  
end
