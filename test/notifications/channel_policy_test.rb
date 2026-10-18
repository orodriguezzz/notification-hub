require "test_helper"

class Notifications::ChannelPolicyTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # Canal falso para demostrar la extensión: renderer + adaptador + registro + una línea en la política.
  # Ninguna definición de app/notifications cambia.
  class FakeSmsRenderer < Notifications::Channels::BaseRenderer
    Message = Data.define(:text)

    def render(content:, overrides:, recipient:, locale:)
      Message.new(text: "#{content.title}: #{content.body}")
    end
  end

  class FakeSmsAdapter < Notifications::Channels::BaseAdapter
    cattr_accessor :sent, default: []

    def provider_name = "fake_sms"
    def contact_for(recipient) = recipient.phone.presence

    def deliver(message:, delivery:)
      sent << { to: delivery.address, text: message.text }
      "sms-#{sent.size}"
    end
  end

  setup do
    FakeSmsAdapter.sent = []
    Notifications::Channels::Registry.register(:fake_sms, renderer: FakeSmsRenderer, adapter: FakeSmsAdapter)
    travel_to Time.find_zone("America/Santiago").local(Date.current.year, Date.current.month, Date.current.day, 12, 0)
  end

  teardown { Notifications::Channels::Registry.unregister(:fake_sms) }

  test "la política carga las tres categorías con sus estrategias" do
    policy = Notifications::Policy.current

    assert_equal :fallback, policy.rule_for(:critical).strategy
    assert policy.rule_for(:critical).bypass_preferences?
    assert_equal :first_available, policy.rule_for(:engagement).strategy
    assert_equal 2, policy.rate_limit_for(:engagement).max
    assert_equal :digest, policy.rate_limit_for(:engagement).overflow
    assert_equal "21:00", policy.quiet_hours.from
  end

  test "crítica sin canal posible queda undeliverable e instrumenta la alerta" do
    events = []
    handle = deliver_signed_copy(employees(:bruno))

    ActiveSupport::Notifications.subscribed(->(event) { events << event }, "undeliverable.notifications") do
      dispatch(handle)
    end

    request = NotificationRequest.find(handle.id)
    assert_equal "undeliverable", request.status
    assert_equal "no_contact", request.status_reason
    assert_includes event_types_for(request), "undeliverable"
    assert_equal 1, events.size
    assert_equal "signed_document_copy", events.first.payload[:notification_key]
  end

  test "no crítica sin canal posible queda skipped" do
    request = dispatch(BirthdayNotification.deliver(to: employees(:diego), params: { company: companies(:acme_cl) }))

    assert_equal "skipped", request.status
    assert_equal "opted_out", request.status_reason
    assert_empty sent_emails
  end

  test "agregar un canal a la política lo usa sin tocar las definiciones" do
    use_policy(shadow_mode: true) { |policy| policy.rule_for(:operational).channels = [ :fake_sms ] }

    request = dispatch(deliver_payslip(employees(:ana)))

    assert_equal "completed", request.status
    assert_equal "fake_sms", request.deliveries.sole.channel
    assert_equal employees(:ana).phone, FakeSmsAdapter.sent.sole[:to]
    assert_empty sent_emails
  end

  test "fallback: si email falla de forma definitiva, la crítica sale por el siguiente canal" do
    use_policy(shadow_mode: true) { |policy| policy.rule_for(:critical).channels = [ :email, :fake_sms ] }
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::PermanentDeliveryError, "550 buzón inexistente")

    request = dispatch(deliver_signed_copy(employees(:ana)))

    assert_equal "completed", request.status
    assert_equal %w[email:failed fake_sms:sent], request.deliveries.order(:id).map { "#{_1.channel}:#{_1.status}" }
    assert_includes event_types_for(request), "fallback_triggered"
  end

  test "first_available no intenta otros canales" do
    use_policy(shadow_mode: true) { |policy| policy.rule_for(:operational).channels = [ :email, :fake_sms ] }
    Notifications::Channels::Email::TestAdapter.fail_next!(Notifications::PermanentDeliveryError, "400")

    request = dispatch(deliver_payslip(employees(:ana)))

    assert_equal "failed", request.status
    assert_empty FakeSmsAdapter.sent
  end
end
