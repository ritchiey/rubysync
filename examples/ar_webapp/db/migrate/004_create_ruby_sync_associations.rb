class CreateRubySyncAssociations < ActiveRecord::Migration
  def self.up
    create_table "ruby_sync_associations" do |t|
      t.column "context",  :string
      t.column "key",     :string
      t.column "synchronizable_id", :string
      t.column "synchronizable_type", :string
    end
    add_index "ruby_sync_associations", [:context, :key], :unique => true
    add_index "ruby_sync_associations", [:synchronizable_id]
  end

  def self.down
    remove_index :ruby_sync_associations, [:context, :key]
    remove_index :ruby_sync_associations, :synchronizable_id
    drop_table :ruby_sync_associations
  end
end
