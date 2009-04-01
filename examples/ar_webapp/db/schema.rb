# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 9) do

  create_table "hobbies", :force => true do |t|
    t.string "name"
  end

  create_table "interests", :force => true do |t|
    t.integer "person_id"
    t.integer "hobby_id"
  end

  create_table "people", :force => true do |t|
    t.string "first_name"
    t.string "last_name"
  end

  create_table "ruby_sync_associations", :force => true do |t|
    t.string  "context"
    t.string  "key"
    t.integer "synchronizable_id"
    t.string  "synchronizable_type"
  end

  add_index "ruby_sync_associations", ["context", "key"], :name => "index_ruby_sync_associations_on_context_and_key", :unique => true
  add_index "ruby_sync_associations", ["synchronizable_id"], :name => "index_ruby_sync_associations_on_synchronizable_id"

  create_table "ruby_sync_events", :force => true do |t|
    t.time    "timestamp"
    t.string  "event_type",     :limit => 8
    t.integer "trackable_id"
    t.string  "trackable_type"
  end

  add_index "ruby_sync_events", ["timestamp"], :name => "index_ruby_sync_events_on_timestamp"

  create_table "ruby_sync_operations", :force => true do |t|
    t.string  "operation",          :limit => 8
    t.string  "field_name"
    t.integer "ruby_sync_event_id"
  end

  add_index "ruby_sync_operations", ["ruby_sync_event_id"], :name => "index_ruby_sync_operations_on_ruby_sync_event_id"

  create_table "ruby_sync_states", :force => true do |t|
  end

  create_table "ruby_sync_values", :force => true do |t|
    t.integer "ruby_sync_operation_id"
    t.string  "value"
  end

end
