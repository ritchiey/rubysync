class CreateAssociationKeys < ActiveRecord::Migration
  def self.up
    create_table :association_keys do |t|
      t.column  :value, :string
      t.column  :record_id, :integer
    end
    add_index :association_keys, :value
    add_index :association_keys, :record_id
  end

  def self.down
    remove_index :association_keys, :value
    remove_index :association_keys, :record_id
    drop_table :association_keys
  end
end
