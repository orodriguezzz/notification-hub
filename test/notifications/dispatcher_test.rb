require "test_helper"

class Notifications::DispatcherTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @employee = employees(:ana)
    # Mediodía en Santiago: fuera del horario de silencio
    travel_to Time.find_zone("America/Santiago").local(Date.current.year, Date.current.month, Date.current.day, 12, 0)
  end

  test "despacha por email: crea la entrega, la marca enviada y completa el request" do
    request = dispatch(deliver_payslip(employees(:ana)))

    assert_equal "completed", request.status
    delivery = request.deliveries.sole
    assert_equal "sent", delivery.status
    assert_equal "email", delivery.channel
    assert_equal "test", delivery.provider
    assert_equal @employee.email, delivery.address
    assert_equal "Tu liquidación de septiembre de 2026 está disponible", delivery.subject
    assert delivery.provider_message_id.present?
    assert_equal 1, delivery.attempts
    assert_equal %w[enqueued sent], event_types_for(request)

    email = sent_emails.sole
    assert_equal @employee.email, email[:to]
    assert_equal delivery.id, email[:delivery_id]
    assert_includes email[:html], "Ver liquidación"
  end

  test "cifra dirección, asunto y cuerpo en la base de datos" do
    request = dispatch(BirthdayNotification.deliver(to: @employee, params: { company: companies(:acme_cl) }))
    delivery = request.deliveries.sole

    raw = NotificationDelivery.connection.select_one(
      "SELECT address, subject, body_text FROM notification_deliveries WHERE id = '#{delivery.id}'"
    )
    assert_not_includes raw["address"], @employee.email
    assert_not_includes raw["subject"], "cumpleaños"
    assert_equal @employee.email, delivery.address
  end

  test "usa el layout del override de email" do
    dispatch(BirthdayNotification.deliver(to: @employee, params: { company: companies(:acme_cl) }))
    assert_includes sent_emails.sole[:html], "🎉"
  end

  test "es idempotente: un segundo despacho no hace nada" do
    handle = BirthdayNotification.deliver(to: @employee, params: { company: companies(:acme_cl) })
    dispatch(handle)
    dispatch(handle)

    assert_equal 1, sent_emails.size
  end

  test "si la entidad ya no existe el request queda skipped por entity_missing" do
    handle = BirthdayNotification.deliver(to: @employee, params: { company: companies(:acme_cl) })
    @employee.delete

    request = dispatch(handle)

    assert_equal "skipped", request.status
    assert_equal "entity_missing", request.status_reason
    assert_empty sent_emails
  end

  test "si expires_at pasó el request queda expired" do
    handle = SurveyReminderNotification.deliver(to: @employee, params: { survey_title: "Clima" })
    travel 3.days

    request = dispatch(handle)

    assert_equal "expired", request.status
    assert_includes event_types_for(request), "expired"
  end

  test "un error transitorio deja la entrega pendiente y el job se reintenta" do
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::TransientDeliveryError, "429")
    handle = deliver_payslip(@employee)

    assert_difference -> { dispatch_jobs.count }, 1 do
      Notifications::DispatchJob.perform_now(handle.id)
    end

    request = NotificationRequest.find(handle.id)
    assert_equal "accepted", request.status
    delivery = request.deliveries.sole
    assert_equal "pending", delivery.status
    assert_equal "429", delivery.last_error

    # El reintento reenvía la misma entrega, sin crear otra
    Notifications::DispatchJob.perform_now(handle.id)
    assert_equal "completed", request.reload.status
    assert_equal [ "sent" ], request.deliveries.pluck(:status)
    assert_equal 2, delivery.reload.attempts
  end

  test "un error definitivo marca la entrega failed y registra el evento" do
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::PermanentDeliveryError, "400 bad request")
    handle = deliver_payslip(@employee)

    request = dispatch(handle)

    assert_equal "failed", request.status
    assert_equal "failed", request.deliveries.sole.status
    assert_includes event_types_for(request), "failed"
  end

  test "agotar los reintentos marca la entrega como failed" do
    handle = deliver_payslip(@employee)
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::TransientDeliveryError, "503")
    assert_raises(Notifications::TransientDeliveryError) { Notifications::Dispatcher.call(handle.id) }

    Notifications::Dispatcher.new(handle.id).give_up(Notifications::TransientDeliveryError.new("503"))

    request = NotificationRequest.find(handle.id)
    assert_equal "failed", request.status
    assert_equal "failed", request.deliveries.sole.status
  end
end
