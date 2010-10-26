class RubySyncOperation < ActiveRecord::Base
  
  belongs_to :event,
            :class_name => "RubySyncEvent",
            :foreign_key => "ruby_sync_event_id"
            
  has_many :values,
          :class_name => "RubySyncValue",
          :foreign_key => "ruby_sync_operation_id"
          
          
  def self.create_for record, type
    record.changed.map do |column|
      values = [ RubySyncValue.new(:value => record.send(column).to_s) ]
      RubySyncOperation.new :operation => type, :field_name => column, :values => values
    end
  end
  
end
