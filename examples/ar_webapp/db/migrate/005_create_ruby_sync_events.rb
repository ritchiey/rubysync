class CreateRubySyncEvents < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_events do |t|
      t.column 'timestamp', :datetime
      t.column 'event_type', :string, :limit => 8
      t.column 'trackable_id', :string
      t.column 'trackable_type', :string
      t.column 'ruby_sync_state_id', :integer
    end
    add_index :ruby_sync_events, :timestamp
    add_index :ruby_sync_events, [:ruby_sync_state_id]
  end

  def self.down
    remove_index :ruby_sync_events, :timestamp
    remove_index :ruby_sync_events, [:ruby_sync_state_id]
    drop_table :ruby_sync_events
  end
end
