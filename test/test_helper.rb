ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Ninguna llamada HTTP real durante los tests
WebMock.disable_net_connect!

# Las particiones del esquema dependen de la fecha en que se generó structure.sql:
# se aseguran las del mes anterior, el actual y los siguientes antes de correr los tests.
Notifications::Partitions.ensure!(from: Date.current.prev_month, months_ahead: 3)

module NotificationTestHelper
  extend ActiveSupport::Concern

  included do
    setup { Notifications::Channels::Email::TestAdapter.clear! }
  end

  # Reemplaza la política para el resto del test (el teardown restaura la de config/).
  # Por defecto desactiva el modo sombra para que el filtro bloquee de verdad.
  def use_policy(shadow_mode: false)
    policy = Notifications::Policy.current.deep_copy
    policy.shadow_mode = shadow_mode
    yield policy if block_given?
    Notifications::Policy.current = policy
  end

  # Envíos de ejemplo de cada categoría
  def deliver_payslip(employee, period: Date.new(2026, 9, 1))
    PayslipAvailableNotification.deliver(to: employee, params: { period: period })
  end

  def deliver_signed_copy(employee, title: "Anexo de contrato")
    SignedDocumentCopyNotification.deliver(to: employee,
                                           params: { document_title: title, signed_at: Time.utc(2026, 10, 1, 15) })
  end

  def deliver_leave_approved(employee)
    LeaveRequestApprovedNotification.deliver(
      to: employee, params: { starts_on: Date.new(2026, 12, 21), ends_on: Date.new(2026, 12, 31), approver_name: "Paula Admin" }
    )
  end

  def dispatch(handle_or_id)
    id = handle_or_id.respond_to?(:id) ? handle_or_id.id : handle_or_id
    Notifications::Dispatcher.call(id)
    NotificationRequest.find(id)
  end

  def sent_emails
    Notifications::Channels::Email::TestAdapter.deliveries
  end

  def event_types_for(request)
    NotificationEvent.where(request_id: request.id).chronological.pluck(:event_type)
  end

  def dispatch_jobs
    SolidQueue::Job.where(class_name: "Notifications::DispatchJob")
  end
end

module ActiveSupport
  class TestCase
    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include NotificationTestHelper

    teardown { ::Notifications::Policy.load_default! }
  end
end
