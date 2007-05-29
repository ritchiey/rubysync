require File.dirname(__FILE__) + '/../test_helper'

class RubySyncObserverTest < Test::Unit::TestCase
  fixtures :people

  def test_destroy
    assert_nil RubySyncEvent.find_by_event_type('delete'), "Delete events already present"
    Person.destroy people('bob')
    event = RubySyncEvent.find_by_event_type 'delete'
    assert_not_nil event, "Delete event not created on destroy"
    assert_equal people('bob').id, event.trackable_id
    assert_equal 'Person', event.trackable_type
  end


  def test_add
    assert_nil RubySyncEvent.find_by_event_type('add'), "Add events already present"
    p = Person.create(:first_name=>"Ritchie", :last_name=>"Young")
    event = RubySyncEvent.find_by_event_type 'add'
    assert_not_nil event, "Add event not created on create"
    assert_equal p.id, event.trackable_id
    assert_equal 'Person', event.trackable_type
    # Ensure the fields were populated correctly
    fn = event.operations.find_by_operation_and_field_name 'add', 'first_name'
    assert_not_nil fn, "No add first_name operation"
    assert_equal 1, fn.values.length
    assert_equal "Ritchie", fn.values[0].value 
    fn = event.operations.find_by_operation_and_field_name 'add', 'last_name'
    assert_not_nil fn, "No add last_name operation"
    assert_equal 1, fn.values.length
    assert_equal "Young", fn.values[0].value
    #TODO: Add support for multi-value fields (AKA has_many associations)
  end


  def test_modify
    assert_nil RubySyncEvent.find_by_event_type('modify'), "Modify events already present"
    p = Person.find people('bob').id
    assert_not_nil p, "Couldn't find bob"
    p.first_name = "Mary"
    p.save
    event = RubySyncEvent.find_by_event_type 'modify'
    assert_not_nil event, "Modify event not created on save"
    assert_equal people('bob').id, event.trackable_id
    assert_equal 'Person', event.trackable_type
    # Ensure the fields were populated correctly
    fn = event.operations.find_by_operation_and_field_name 'replace', 'first_name'
    assert_not_nil fn, "No replace first_name operation"
    assert_equal 1, fn.values.length
    assert_equal "Mary", fn.values[0].value 
    #TODO: Add support for multi-value fields (AKA has_many associations)
  end



  
end
