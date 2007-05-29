class CreateRubySyncEvents < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_events do |t|
      t.column 'timestamp', :time
      t.column 'event_type', :string, :limit=>8
      t.column 'trackable_id', :integer
      t.column 'trackable_type', :string
    end
    add_index :ruby_sync_events, :timestamp
  end

  def self.down
    remove_index :ruby_sync_events, :timestamp
    drop_table :ruby_sync_events
  end
end
