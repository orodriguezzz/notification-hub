require "test_helper"

class Notifications::SendgridAdapterTest < ActiveSupport::TestCase
  ENDPOINT = "https://api.sendgrid.com/v3/mail/send".freeze

  setup do
    @adapter = Notifications::Channels::Email::SendgridAdapter.new(api_key: "SG.test", from: "no-reply@hub.test", sandbox: true)
    @message = Notifications::Channels::Email::Renderer::Message.new(subject: "Asunto", html: "<p>Hola</p>", text: "Hola")
  end

  test "envía a mail/send con custom_args, sandbox y List-Unsubscribe para engagement" do
    stub = stub_request(:post, ENDPOINT).to_return(status: 202, headers: { "X-Message-Id" => "sg-123" })

    message_id = @adapter.deliver(message: @message, delivery: build_delivery(category: "engagement"))

    assert_equal "sg-123", message_id
    assert_requested stub
    assert_requested(:post, ENDPOINT) do |request|
      body = JSON.parse(request.body)
      assert_equal "Bearer SG.test", request.headers["Authorization"]
      assert_equal "ana.rojas@acme.test", body.dig("personalizations", 0, "to", 0, "email")
      assert_equal "no-reply@hub.test", body.dig("from", "email")
      assert_equal %w[delivery_id request_id], body["custom_args"].keys.sort
      assert_equal true, body.dig("mail_settings", "sandbox_mode", "enable")
      assert_match %r{\A<http://test\.host/unsubscribe/.+>\z}, body.dig("headers", "List-Unsubscribe")
      assert_equal "List-Unsubscribe=One-Click", body.dig("headers", "List-Unsubscribe-Post")
      assert_equal %w[text/plain text/html], body["content"].map { _1["type"] }
    end
  end

  test "no agrega headers de desuscripción fuera de engagement" do
    stub_request(:post, ENDPOINT).to_return(status: 202)

    @adapter.deliver(message: @message, delivery: build_delivery(category: "critical"))

    assert_requested(:post, ENDPOINT) { |request| assert_nil JSON.parse(request.body)["headers"] }
  end

  test "429 y 5xx son errores transitorios" do
    stub_request(:post, ENDPOINT).to_return(status: 429).then.to_return(status: 503)

    assert_raises(Notifications::TransientDeliveryError) { @adapter.deliver(message: @message, delivery: build_delivery) }
    assert_raises(Notifications::TransientDeliveryError) { @adapter.deliver(message: @message, delivery: build_delivery) }
  end

  test "4xx (salvo 429) es un error definitivo" do
    stub_request(:post, ENDPOINT).to_return(status: 400, body: '{"errors":[{"message":"invalid email"}]}')

    error = assert_raises(Notifications::PermanentDeliveryError) do
      @adapter.deliver(message: @message, delivery: build_delivery)
    end
    assert_match "400", error.message
  end

  test "un error de red es transitorio" do
    stub_request(:post, ENDPOINT).to_timeout

    assert_raises(Notifications::TransientDeliveryError) { @adapter.deliver(message: @message, delivery: build_delivery) }
  end

  private

  def build_delivery(category: "operational")
    NotificationDelivery.new(
      id: SecureRandom.uuid_v7, request_id: SecureRandom.uuid_v7, company_id: companies(:acme_cl).id,
      notification_key: "birthday", category: category, recipient_type: "Employee",
      recipient_id: employees(:ana).id, channel: "email", address: employees(:ana).email
    )
  end
end
