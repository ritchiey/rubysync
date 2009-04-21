class CreateAssociationTracks < ActiveRecord::Migration
  def self.up
    create_table :association_tracks do |t|
      t.column :context,  :string
      t.column :key,     :string
      t.column :synchronizable_id, :integer
      t.column :synchronizable_type, :string
    end
    add_index :association_tracks, [:context, :key], :unique=>true
    add_index :association_tracks, [:synchronizable_id]
  end

  def self.down
    remove_index :association_tracks, [:context, :key]
    remove_index :association_tracks, :synchronizable_id
    drop_table :association_tracks
  end
end
