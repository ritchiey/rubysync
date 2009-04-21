class CreateChangeTracks < ActiveRecord::Migration
  def self.up
    create_table :change_tracks do |t|
      t.string :key
      t.text :digest

      t.timestamps
    end
    add_index :change_tracks, :key, :unique => true
  end

  def self.down
    remove_index :change_tracks, :key
    drop_table :change_tracks
  end
end
