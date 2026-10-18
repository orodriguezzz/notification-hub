require "test_helper"

class Webhooks::SendgridControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @key = OpenSSL::PKey::EC.generate("prime256v1")
    @original_key = Rails.configuration.x.notifications.webhook_public_key
    Rails.configuration.x.notifications.webhook_public_key = Base64.strict_encode64(@key.public_to_der)
    travel_to Time.find_zone("America/Santiago").local(Date.current.year, Date.current.month, Date.current.day, 12, 0)
  end

  teardown { Rails.configuration.x.notifications.webhook_public_key = @original_key }

  test "firma inválida responde 401" do
    post webhooks_sendgrid_path, params: "[]", headers: {
      "Content-Type" => "application/json",
      "X-Twilio-Email-Event-Webhook-Signature" => Base64.strict_encode64("firma-falsa"),
      "X-Twilio-Email-Event-Webhook-Timestamp" => Time.current.to_i.to_s
    }

    assert_response :unauthorized
  end

  test "sin headers de firma responde 401" do
    post webhooks_sendgrid_path, params: "[]", headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "firma válida encola el lote y responde 202" do
    assert_difference -> { SolidQueue::Job.where(class_name: "Notifications::WebhookEventsJob").count }, 1 do
      signed_post([ { "event" => "open", "delivery_id" => SecureRandom.uuid } ])
    end

    assert_response :accepted
  end

  test "rechaza un lote firmado con un timestamp antiguo (replay)" do
    assert_no_difference -> { SolidQueue::Job.where(class_name: "Notifications::WebhookEventsJob").count } do
      signed_post([ { "event" => "open", "delivery_id" => SecureRandom.uuid } ], timestamp: 20.minutes.ago.to_i.to_s)
    end

    assert_response :unauthorized
  end

  test "rechaza un timestamp que no es numérico" do
    signed_post([ { "event" => "open", "delivery_id" => SecureRandom.uuid } ], timestamp: "ayer")
    assert_response :unauthorized
  end

  test "actualiza estados de forma idempotente" do
    delivery = sent_delivery
    events = [ sendgrid_event(delivery, "delivered", "sg-1"), sendgrid_event(delivery, "open", "sg-2") ]

    Notifications::WebhookEventsJob.perform_now(events)
    Notifications::WebhookEventsJob.perform_now(events)

    assert_equal "delivered", delivery.reload.status
    assert_equal 1, NotificationEvent.where(delivery_id: delivery.id, event_type: "delivered").count
    assert_equal 1, NotificationEvent.where(delivery_id: delivery.id, event_type: "opened").count
  end

  test "bounce marca la entrega como bounced y no retrocede a delivered" do
    delivery = sent_delivery
    Notifications::WebhookEventsJob.perform_now([ sendgrid_event(delivery, "bounce", "sg-3") ])
    Notifications::WebhookEventsJob.perform_now([ sendgrid_event(delivery, "delivered", "sg-4") ])

    assert_equal "bounced", delivery.reload.status
  end

  test "spamreport y unsubscribe desuscriben de engagement" do
    delivery = sent_delivery
    Notifications::WebhookEventsJob.perform_now([ sendgrid_event(delivery, "spamreport", "sg-5") ])

    assert employees(:ana).reload.opted_out?(:engagement)
    assert_equal 1, NotificationEvent.where(delivery_id: delivery.id, event_type: "spam_report").count
  end

  test "bounce de una crítica sin otro canal: fallback_triggered y undeliverable con alerta" do
    alerts = []
    delivery = sent_delivery(deliver_signed_copy(employees(:ana)))

    ActiveSupport::Notifications.subscribed(->(event) { alerts << event }, "undeliverable.notifications") do
      Notifications::WebhookEventsJob.perform_now([ sendgrid_event(delivery, "bounce", "sg-6") ])
    end

    request = delivery.request.reload
    assert_equal "undeliverable", request.status
    assert_equal "bounced", request.status_reason
    assert_includes event_types_for(request), "fallback_triggered"
    assert_equal 1, alerts.size
  end

  private

  def signed_post(events, timestamp: Time.current.to_i.to_s)
    payload = events.to_json
    signature = Base64.strict_encode64(@key.dsa_sign_asn1(Digest::SHA256.digest("#{timestamp}#{payload}")))

    post webhooks_sendgrid_path, params: payload, headers: {
      "Content-Type" => "application/json",
      "X-Twilio-Email-Event-Webhook-Signature" => signature,
      "X-Twilio-Email-Event-Webhook-Timestamp" => timestamp
    }
  end

  def sent_delivery(handle = nil)
    handle ||= deliver_payslip(employees(:ana))
    dispatch(handle).deliveries.sole
  end

  def sendgrid_event(delivery, event, sg_event_id)
    { "event" => event, "sg_event_id" => sg_event_id, "timestamp" => Time.current.to_i,
      "delivery_id" => delivery.id, "request_id" => delivery.request_id, "email" => delivery.address }
  end
end
