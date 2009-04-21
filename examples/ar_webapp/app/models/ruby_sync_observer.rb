class RubySyncObserver < ActiveRecord::Observer

  observe Person

  def after_create record
    RubySyncEvent.create  :timestamp=> Time.now,
                          :event_type=>'add',
                          :trackable_id=>record.id,
                          :trackable_type=>record.class.name,
                          :operations => RubySyncOperation.create_for(record, 'add')
  end
  
  def before_update record
    RubySyncEvent.create  :timestamp=> Time.now,
                          :event_type=>'modify',
                          :trackable_id=>record.id,
                          :trackable_type=>record.class.name,
                          :operations => RubySyncOperation.create_for(record, 'replace')
  end
  
  def after_destroy record
    RubySyncEvent.create  :timestamp=> Time.now,
                          :event_type=>'delete',
                          :trackable_id=>record.id,
                          :trackable_type=>record.class.name
  end

  def after_destroy_all records
    record.each do |record|
      RubySyncEvent.create  :timestamp=> Time.now,
                          :event_type=>'delete',
                          :trackable_id=>record.id,
                          :trackable_type=>record.class.name
    end
  end

end