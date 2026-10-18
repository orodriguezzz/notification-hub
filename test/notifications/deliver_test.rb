require "test_helper"

class Notifications::DeliverTest < ActiveSupport::TestCase
  setup do
    @employee = employees(:ana)
    @company = companies(:acme_cl)
  end

  test "deliver registra request, clave de idempotencia, evento y job, y devuelve un handle" do
    handle = nil

    assert_difference -> { NotificationRequest.count } => 1, -> { dispatch_jobs.count } => 1,
                      -> { NotificationIdempotencyKey.count } => 1 do
      handle = BirthdayNotification.deliver(to: @employee, params: { company: @company })
    end

    assert_equal :accepted, handle.status
    request = NotificationRequest.find(handle.id)
    assert_equal "accepted", request.status
    assert_equal "birthday", request.notification_key
    assert_equal "engagement", request.category
    assert_equal @company.id, request.company_id
    assert_equal [ "Employee", @employee.id ], [ request.recipient_type, request.recipient_id ]
    assert_equal "#{@employee.id}:#{Date.current}", request.idempotency_key
    assert_in_delta 2.days.from_now, request.expires_at, 5.seconds
    assert_equal [ "enqueued" ], event_types_for(request)

    job = dispatch_jobs.last
    assert_equal "bulk", job.queue_name
    assert_equal [ handle.id ], job.arguments["arguments"]
  end

  test "la cola depende de la categoría" do
    deliver_signed_copy(employees(:ana))
    deliver_payslip(employees(:ana))

    assert_equal %w[critical default], dispatch_jobs.order(:id).last(2).map(&:queue_name)
  end

  test "dos deliver con la misma clave generan un solo request y el segundo es :duplicate" do
    first = BirthdayNotification.deliver(to: @employee, params: { company: @company }, idempotency_key: "k-1")

    second = nil
    assert_no_difference [ -> { NotificationRequest.count }, -> { dispatch_jobs.count } ] do
      second = BirthdayNotification.deliver(to: @employee, params: { company: @company }, idempotency_key: "k-1")
    end

    assert_equal :accepted, first.status
    assert_equal :duplicate, second.status
    assert_equal first.id, second.id
  end

  test "dedupe_by define la clave por defecto" do
    first = BirthdayNotification.deliver(to: @employee, params: { company: @company })
    second = BirthdayNotification.deliver(to: @employee, params: { company: @company })

    assert second.duplicate?
    assert_equal first.id, second.id
  end

  test "sin clave explícita ni dedupe_by cada envío es distinto" do
    first = SurveyReminderNotification.deliver(to: @employee, params: { survey_title: "Clima" })
    second = SurveyReminderNotification.deliver(to: @employee, params: { survey_title: "Clima" })

    assert first.accepted?
    assert second.accepted?
    assert_not_equal first.id, second.id
  end

  test "si la transacción del llamador hace rollback no queda ni request ni job" do
    assert_no_difference [ -> { NotificationRequest.count }, -> { dispatch_jobs.count },
                           -> { NotificationIdempotencyKey.count }, -> { NotificationEvent.count } ] do
      ApplicationRecord.transaction(requires_new: true) do
        @employee.update!(phone: "+56900000000")
        BirthdayNotification.deliver(to: @employee, params: { company: @company })
        raise ActiveRecord::Rollback
      end
    end

    assert_not_equal "+56900000000", @employee.reload.phone
  end

  test "deliver no hace llamadas HTTP" do
    BirthdayNotification.deliver(to: @employee, params: { company: @company })
    deliver_signed_copy(@employee)

    assert_not_requested :any, /.*/
    assert_empty sent_emails
  end

  test "valida parámetros: faltante o no declarado falla rápido" do
    error = assert_raises(Notifications::InvalidParamsError) { BirthdayNotification.deliver(to: @employee) }
    assert_match "company", error.message

    error = assert_raises(Notifications::InvalidParamsError) do
      BirthdayNotification.deliver(to: @employee, params: { company: @company, color: "rojo" })
    end
    assert_match "color", error.message

    assert_raises(Notifications::InvalidParamsError) do
      BirthdayNotification.deliver(to: users(:admin_cl), params: { company: @company })
    end
  end

  test "guarda los modelos como GlobalID" do
    handle = BirthdayNotification.deliver(to: @employee, params: { company: @company })
    params = NotificationRequest.find(handle.id).params

    assert_equal @company.to_global_id.to_s, params.dig("company", "_aj_globalid")
    assert_equal @employee.to_global_id.to_s, params.dig("employee", "_aj_globalid")
  end

  test "captura el origen desde Current" do
    handle = Current.set(user: users(:admin_cl), request_id: "req-123", job: "AlgunJob#1") do
      deliver_leave_approved(@employee)
    end

    origin = NotificationRequest.find(handle.id).origin
    assert_equal users(:admin_cl).id, origin["user_id"]
    assert_equal "req-123", origin["request_id"]
    assert_equal "AlgunJob#1", origin["job"]
  end

  test "sent es un alias de deliver" do
    handle = BirthdayNotification.sent(to: @employee, params: { company: @company })
    assert handle.accepted?
  end

  test "deliver_many devuelve un handle por destinatario e inserta en lote" do
    recipients = [ employees(:ana), employees(:bruno), employees(:diego) ]

    handles = nil
    assert_difference -> { NotificationRequest.count } => 3, -> { dispatch_jobs.count } => 3 do
      handles = BirthdayNotification.deliver_many(to: recipients, params: { company: @company })
    end

    assert_equal 3, handles.size
    assert handles.all?(&:accepted?)
    assert_equal recipients.map(&:id), handles.map { |handle| NotificationRequest.find(handle.id).recipient_id }

    again = BirthdayNotification.deliver_many(to: recipients, params: { company: @company })
    assert again.all?(&:duplicate?)
    assert_equal handles.map(&:id), again.map(&:id)
  end

  test "deliver_many acepta una relación" do
    handles = BirthdayNotification.deliver_many(to: @company.employees, params: { company: @company })
    assert_equal @company.employees.count, handles.size
  end
end
