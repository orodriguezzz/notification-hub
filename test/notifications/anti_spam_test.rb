require "test_helper"

# Engagement sin cooldown ni dedupe: permite probar el presupuesto diario y el digest
class AntiSpamEngagementNotification < ApplicationNotification
  key :anti_spam_engagement
  category :engagement
  owner :platform_team
  recipient :employee

  param :employee, required: true
  param :topic, required: true

  content do |p|
    title "Novedad: #{p.topic}"
    body "Detalle de #{p.topic}"
  end

  preview { { employee: Employee.first, topic: "Ejemplo" } }
end

class Notifications::AntiSpamTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  SANTIAGO = ActiveSupport::TimeZone["America/Santiago"]
  MEXICO = ActiveSupport::TimeZone["America/Mexico_City"]

  setup do
    use_policy(shadow_mode: false)
    @ana = employees(:ana)     # Santiago
    @carla = employees(:carla) # Ciudad de México
  end

  test "presupuesto diario: el excedente de engagement va al digest de las 08:00 locales" do
    at_local(SANTIAGO, 12)

    results = 3.times.map { |i| dispatch(engagement(@ana, "Encuesta #{i}")) }

    assert_equal %w[completed completed deferred], results.map(&:status)
    deferred = results.last
    assert_equal "digest", deferred.status_reason
    assert_equal SANTIAGO.local(*tomorrow(SANTIAGO), 8, 0), deferred.scheduled_at
    assert_equal 2, sent_emails.size
  end

  test "presupuesto diario: el excedente de operational se posterga al día siguiente" do
    at_local(SANTIAGO, 12)
    use_policy { |policy| policy.rate_limits[:operational].max = 1 }

    first = dispatch(payslip_for(@ana, 1))
    second = dispatch(payslip_for(@ana, 2))

    assert_equal "completed", first.status
    assert_equal "deferred", second.status
    assert_equal "rate_limit", second.status_reason
    assert_equal SANTIAGO.local(*tomorrow(SANTIAGO), 8, 0), second.scheduled_at
    # Se reencola para esa hora
    assert dispatch_jobs.where(scheduled_at: second.scheduled_at).exists?
  end

  test "las críticas están exentas pero se cuentan" do
    at_local(SANTIAGO, 23) # incluso en horario de silencio
    use_policy { |policy| policy.rate_limits[:critical] = Notifications::Policy::RateLimit.new(max: 0, overflow: :defer) }

    request = dispatch(deliver_signed_copy(employees(:ana)))

    assert_equal "completed", request.status
    assert_equal 1, NotificationCounter.find_by!(recipient_id: @ana.id, category: "critical").count
  end

  test "cooldown: no repite la misma notificación al mismo destinatario dentro del plazo" do
    at_local(SANTIAGO, 12)

    first = dispatch(survey(@ana, "Clima"))
    travel 1.day
    second = dispatch(survey(@ana, "Clima"))

    assert_equal "completed", first.status
    assert_equal "skipped", second.status
    assert_equal "cooldown", second.status_reason
    assert_includes event_types_for(second), "throttled"
  end

  test "horario de silencio en Santiago: posterga hasta las 08:00 locales" do
    at_local(SANTIAGO, 22, 30)

    request = dispatch(payslip_for(@ana, 1))

    assert_equal "deferred", request.status
    assert_equal "quiet_hours", request.status_reason
    assert_equal SANTIAGO.local(*tomorrow(SANTIAGO), 8, 0), request.scheduled_at
    assert_empty sent_emails
  end

  test "horario de silencio según la zona de cada destinatario (Santiago vs Ciudad de México)" do
    # 22:00 en Ciudad de México; en Santiago es más tarde todavía o igual de noche, así que se usa
    # una hora en la que una zona está en silencio y la otra no.
    mexico_morning = MEXICO.local(Date.current.year, Date.current.month, Date.current.day, 7, 30)
    travel_to mexico_morning
    santiago_local = Time.current.in_time_zone(SANTIAGO)
    assert_not Notifications.policy.quiet_hours.active_at?(santiago_local), "en Santiago ya es de día"

    mx = dispatch(deliver_payslip(@carla))
    cl = dispatch(payslip_for(@ana, 1))

    assert_equal "deferred", mx.status
    assert_equal MEXICO.local(Date.current.year, Date.current.month, Date.current.day, 8, 0),
                 mx.scheduled_at.in_time_zone(MEXICO)
    assert_equal "completed", cl.status
  end

  test "si vence antes de la nueva hora, se descarta como expired" do
    at_local(SANTIAGO, 12)
    2.times { |i| dispatch(engagement(@ana, "Encuesta #{i}")) }
    use_policy { |policy| policy.rate_limits[:engagement].overflow = :defer }

    # SurveyReminder expira en 2 días; se fuerza un vencimiento más cercano
    handle = engagement(@ana, "Encuesta tardía")
    NotificationRequest.where(id: handle.id).update_all(expires_at: 2.hours.from_now)
    request = dispatch(handle)

    assert_equal "expired", request.status
  end

  test "modo sombra: registra throttled_shadow sin bloquear" do
    at_local(SANTIAGO, 23)
    use_policy(shadow_mode: true)

    request = dispatch(payslip_for(@ana, 1))

    assert_equal "completed", request.status
    assert_equal 1, sent_emails.size
    shadow = NotificationEvent.find_by!(request_id: request.id, event_type: "throttled_shadow")
    assert_equal "defer", shadow.payload["action"]
    assert_equal "quiet_hours", shadow.payload["reason"]
  end

  test "el modo sombra está activado por defecto" do
    Notifications::Policy.load_default!
    assert Notifications.policy.shadow_mode?
  end

  test "digest: varias engagement postergadas generan un solo correo" do
    at_local(SANTIAGO, 12)
    use_policy { |policy| policy.rate_limits[:engagement].max = 0 }
    handles = 3.times.map { |i| engagement(@ana, "Encuesta #{i}") }
    handles.each { dispatch(_1) }
    assert_empty sent_emails

    travel_to SANTIAGO.local(*tomorrow(SANTIAGO), 8, 0)
    Notifications::DigestJob.perform_now

    email = sent_emails.sole
    assert_equal "Tienes 3 novedades", email[:subject]
    3.times { |i| assert_includes email[:html], "Encuesta #{i}" }

    requests = NotificationRequest.where(id: handles.map(&:id))
    assert_equal [ "completed" ], requests.pluck(:status).uniq
    assert_equal [ "digested" ], requests.pluck(:status_reason).uniq
    assert_equal 3, NotificationEvent.where(request_id: handles.map(&:id), event_type: "digested").count

    # Una segunda corrida no reenvía
    Notifications::DigestJob.perform_now
    assert_equal 1, sent_emails.size
  end

  test "digest: no envía antes de las 08:00 locales" do
    at_local(SANTIAGO, 12)
    use_policy { |policy| policy.rate_limits[:engagement].max = 0 }
    dispatch(engagement(@ana, "Clima"))

    travel_to SANTIAGO.local(*tomorrow(SANTIAGO), 7, 0)
    Notifications::DigestJob.perform_now

    assert_empty sent_emails
  end

  private

  def at_local(zone, hour, minute = 0)
    today = Time.current.in_time_zone(zone).to_date
    travel_to zone.local(today.year, today.month, today.day, hour, minute)
  end

  def tomorrow(zone)
    date = Time.current.in_time_zone(zone).to_date + 1
    [ date.year, date.month, date.day ]
  end

  def engagement(employee, topic)
    AntiSpamEngagementNotification.deliver(to: employee, params: { topic: topic })
  end

  def survey(employee, title)
    SurveyReminderNotification.deliver(to: employee, params: { survey_title: title })
  end

  def payslip_for(employee, months_ago)
    deliver_payslip(employee, period: Date.current.beginning_of_month << (months_ago + 1))
  end
end
