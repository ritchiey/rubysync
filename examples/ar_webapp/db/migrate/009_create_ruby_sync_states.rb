class CreateRubySyncStates < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_states do |t|
      t.string  :context
      t.string  :info
      t.integer :last_event_id
    end
    add_index :ruby_sync_states, [:last_event_id]
  end

  def self.down
    remove_index :ruby_sync_states, [:last_event_id]
    drop_table :ruby_sync_states
  end
end
