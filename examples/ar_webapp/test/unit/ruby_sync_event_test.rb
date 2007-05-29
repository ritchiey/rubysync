require File.dirname(__FILE__) + '/../test_helper'

class RubySyncEventTest < Test::Unit::TestCase
  fixtures :ruby_sync_events

  # Replace this with your real tests.
  def test_event_type
    assert_nil RubySyncEvent.find_by_event_type(:add), "Already add events"
    event = RubySyncEvent.create :event_type=>:add
    assert_not_nil event = RubySyncEvent.find_by_event_type(:add), "Add event not created"
  end
end
