class RubySyncValue < ActiveRecord::Base
  
  belongs_to :operation,
          :class_name => "RubySyncOperation",
          :foreign_key => "ruby_sync_operation_id"
  
end
