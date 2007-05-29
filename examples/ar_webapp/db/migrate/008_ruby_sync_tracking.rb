# This is a database specific file. This one is for MySQL 5.1. The aim here is to populate
# the RubySyncEvents, RubySyncOperations and RubySyncValues tables appropriately when an
# change occurs to a tracked table. The RubySync database connector then monitors the
# ruby_sync_events table and uses information in there (combined with supporting data in
# ruby_sync_operations and ruby_sync_values).

# In the case of MySQL 5.1 we're using triggers to populate the tracking tables.

class RubySyncTracking < ActiveRecord::Migration
  def self.up
#    execute "create trigger 'ruby_sync_create' before insert on 'people' "
  end

  def self.down
  end
end
