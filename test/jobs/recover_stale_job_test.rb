require "test_helper"

class Notifications::RecoverStaleJobTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    # Mediodía en Santiago: fuera del horario de silencio
    travel_to Time.find_zone("America/Santiago").local(Date.current.year, Date.current.month, Date.current.day, 12, 0)
  end

  test "un request trancado en processing vuelve a accepted, se reencola y termina de enviarse" do
    handle = deliver_payslip(employees(:ana))
    stuck!(handle.id, since: 20.minutes.ago)

    assert_difference -> { dispatch_jobs.count }, 1 do
      assert_equal 1, Notifications::RecoverStaleJob.perform_now
    end

    request = NotificationRequest.find(handle.id)
    assert_equal "accepted", request.status
    assert_equal "recovered", request.status_reason
    assert_includes event_types_for(request), "recovered"

    Notifications::DispatchJob.perform_now(handle.id)
    assert_equal "completed", request.reload.status
    assert_equal 1, sent_emails.size
  end

  test "reenvía la entrega que quedó pendiente, sin crear otra" do
    handle = deliver_payslip(employees(:ana))
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::TransientDeliveryError, "503")
    assert_raises(Notifications::TransientDeliveryError) { Notifications::Dispatcher.call(handle.id) }
    stuck!(handle.id, since: 20.minutes.ago)

    Notifications::RecoverStaleJob.perform_now
    Notifications::DispatchJob.perform_now(handle.id)

    request = NotificationRequest.find(handle.id)
    assert_equal "completed", request.status
    assert_equal [ "sent" ], request.deliveries.pluck(:status)
  end

  test "no toca un request que se está procesando ahora" do
    handle = deliver_payslip(employees(:ana))
    stuck!(handle.id, since: 2.minutes.ago)

    assert_no_difference -> { dispatch_jobs.count } do
      assert_equal 0, Notifications::RecoverStaleJob.perform_now
    end
    assert_equal "processing", NotificationRequest.find(handle.id).status
  end

  test "un digest trancado vuelve a deferred para la próxima corrida de DigestJob, sin encolar despacho" do
    handle = deliver_payslip(employees(:ana))
    stuck!(handle.id, since: 20.minutes.ago, status_reason: "digest")

    assert_no_difference -> { dispatch_jobs.count } do
      Notifications::RecoverStaleJob.perform_now
    end

    request = NotificationRequest.find(handle.id)
    assert_equal "deferred", request.status
    assert_equal "digest", request.status_reason
  end

  private

  # Simula un worker que tomó el request (processing) y se cayó antes de terminar
  def stuck!(id, since:, status_reason: nil)
    NotificationRequest.where(id: id).update_all(status: "processing", status_reason: status_reason, updated_at: since)
  end
end
