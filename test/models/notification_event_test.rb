require "test_helper"

class NotificationEventTest < ActiveSupport::TestCase
  setup do
    handle = BirthdayNotification.deliver(to: employees(:ana), params: { company: companies(:acme_cl) })
    @event = NotificationEvent.find_by!(request_id: handle.id)
  end

  test "un evento persistido es de solo lectura en Active Record" do
    assert @event.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { @event.update!(event_type: "sent") }
  end

  test "la base de datos rechaza UPDATE sobre notification_events" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      NotificationEvent.where(id: @event.id).update_all(event_type: "sent")
    end
    assert_match "append-only", error.message
  end

  test "la base de datos rechaza DELETE sobre notification_events" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      NotificationEvent.where(id: @event.id).delete_all
    end
    assert_match "append-only", error.message
  end
end
