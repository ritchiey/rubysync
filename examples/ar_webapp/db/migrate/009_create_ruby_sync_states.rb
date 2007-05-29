class CreateRubySyncStates < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_states do |t|
    end
  end

  def self.down
    drop_table :ruby_sync_states
  end
end
