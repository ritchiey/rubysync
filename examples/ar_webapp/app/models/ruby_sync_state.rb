class RubySyncState < ActiveRecord::Base

  # context :string # Name of the connector who sync data
  # info :string # A timestamp or a revision number of the last sync
  # last_event_id :integer # Unique identifier of the last parsed event
  belongs_to :last_event, :class_name => 'RubySyncEvent'

end
