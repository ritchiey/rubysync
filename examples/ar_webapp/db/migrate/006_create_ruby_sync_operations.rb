class CreateRubySyncOperations < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_operations do |t|
      t.column 'operation', :string, :limit=>8 # add, delete or replace
      t.column 'field_name', :string
      t.column 'ruby_sync_event_id', :integer
    end
    add_index :ruby_sync_operations, :ruby_sync_event_id
  end

  def self.down
    remove_index :ruby_sync_operations, :ruby_sync_event_id
    drop_table :ruby_sync_operations
  end
end
