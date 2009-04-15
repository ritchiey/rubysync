#require 'person'#Uncomment for run RubySync's test case
class RubySyncObserver < ActiveRecord::Observer

  observe Person

  def after_create record
    event = RubySyncEvent.create  :timestamp=> Time.now,
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

end