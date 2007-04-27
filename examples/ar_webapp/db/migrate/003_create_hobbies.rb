class CreateHobbies < ActiveRecord::Migration
  def self.up
    create_table :hobbies do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :hobbies
  end
end
