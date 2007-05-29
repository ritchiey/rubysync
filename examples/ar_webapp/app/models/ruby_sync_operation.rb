class RubySyncOperation < ActiveRecord::Base
  
  belongs_to :event,
            :class_name => "RubySyncEvent",
            :foreign_key => "ruby_sync_event_id"
            
  has_many :values,
          :class_name => "RubySyncValue",
          :foreign_key => "ruby_sync_operation_id"
          
          
  def self.create_for record, type
    record.class.content_columns.map do |column|
      values = [ RubySyncValue.new(:value=>record[column.name].to_s) ]
      RubySyncOperation.new :operation=>type, :field_name=>column.name, :values=>values
    end
  end

  
end
