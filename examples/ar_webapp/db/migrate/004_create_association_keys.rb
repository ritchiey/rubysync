class CreateAssociationKeys < ActiveRecord::Migration
  def self.up
    create_table "association_keys" do |t|
      t.column "pipeline",  :string
      t.column "value",     :string
      t.column "synchronizable_id", :integer
      t.column "synchronizable_type", :string
    end
    add_index "association_keys", ["pipeline", "value"], :unique=>true
    add_index "association_keys", ["synchronizable_id"]
  end

  def self.down
  #  remove_index :association_keys, [:pipeline, :value]
  #  remove_index :association_keys, :synchronizable_id
    drop_table :association_keys
  end
end
