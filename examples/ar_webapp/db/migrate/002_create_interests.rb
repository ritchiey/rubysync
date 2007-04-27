class CreateInterests < ActiveRecord::Migration
  def self.up
    create_table :interests do |t|
      t.column :person_id, :integer
      t.column :hobby_id, :integer
    end
  end

  def self.down
    drop_table :interests
  end
end
