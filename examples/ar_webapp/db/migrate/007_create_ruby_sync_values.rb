class CreateRubySyncValues < ActiveRecord::Migration
  def self.up
    create_table :ruby_sync_values do |t|
      t.column :ruby_sync_operation_id, :integer
      t.column :value, :string
    end
  end

  def self.down
    drop_table :ruby_sync_values
  end
end
