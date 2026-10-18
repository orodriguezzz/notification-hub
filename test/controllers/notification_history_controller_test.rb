require "test_helper"

class NotificationHistoryControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    santiago = ActiveSupport::TimeZone["America/Santiago"]
    today = Time.current.in_time_zone(santiago).to_date
    travel_to santiago.local(today.year, today.month, today.day, 12, 0)
    use_policy(shadow_mode: false)

    # Acme Chile: una entregada, una postergada por horario, una desuscrita
    @payslip = dispatch(deliver_payslip(employees(:ana)))
    Notifications::WebhookEventsJob.perform_now([ { "event" => "delivered", "sg_event_id" => "sg-1",
                                                    "delivery_id" => @payslip.deliveries.sole.id, "timestamp" => Time.current.to_i } ])
    @opted_out = dispatch(BirthdayNotification.deliver(to: employees(:diego), params: { company: companies(:acme_cl) }))

    # Globex México
    @foreign = dispatch(deliver_leave_approved(employees(:carla)))
  end

  test "un administrador ve el historial de su empresa con estados en lenguaje simple" do
    sign_in users(:admin_cl)
    get notification_history_index_path

    assert_response :success
    assert_select "td", text: /Ana Rojas/
    assert_select "td", text: "Liquidación de sueldo disponible"
    assert_select ".badge", text: "Entregada"
    assert_select ".badge", text: "No enviada: el colaborador se desuscribió"
    # Los estados y keys internos nunca aparecen en el texto visible
    assert_no_match(/payslip_available|opted_out|completed|skipped/, css_select("tbody").text)
  end

  test "muestra la categoría y el canal de cada notificación" do
    sign_in users(:admin_cl)
    get notification_history_index_path(notification_key: "payslip_available")

    assert_select "tbody tr td .category--operational", text: "Operativa"
    assert_select "tbody tr td", text: "Correo electrónico"

    get notification_history_index_path(employee: "diego")
    assert_select "tbody tr td .category--engagement", text: "Relacionamiento"
    assert_select "tbody tr td", text: "—" # desuscrito: no salió por ningún canal
  end

  test "el detalle explica qué significa la categoría" do
    sign_in users(:admin_cl)
    critical = dispatch(deliver_signed_copy(employees(:ana)))
    get notification_history_path(critical.id)

    assert_select "dd .category--critical", text: "Crítica"
    assert_select "dd", text: /Siempre se envía, a cualquier hora/
    assert_select "dd", text: "Correo electrónico"
  end

  test "aislamiento: el administrador de A no ve colaboradores ni entregas de B" do
    sign_in users(:admin_cl)
    get notification_history_index_path

    assert_no_match "Carla", response.body

    get notification_history_path(@foreign.id)
    assert_response :not_found
  end

  test "un usuario member recibe 403" do
    sign_in users(:member_cl)
    get notification_history_index_path

    assert_response :forbidden
  end

  test "filtra por colaborador, tipo y estado" do
    sign_in users(:admin_cl)

    get notification_history_index_path(employee: "diego")
    assert_select "tbody tr", count: 1
    assert_select "td", text: /Diego/

    get notification_history_index_path(notification_key: "payslip_available")
    assert_select "tbody tr", count: 1
    assert_select "td", text: /Ana Rojas/

    get notification_history_index_path(status: "delivered")
    assert_select "tbody tr", count: 1

    get notification_history_index_path(status: "not_sent")
    assert_select "tbody tr", count: 1
    assert_select ".badge", text: "No enviada: el colaborador se desuscribió"
  end

  test "filtra por rango de fechas" do
    sign_in users(:admin_cl)

    get notification_history_index_path(from: Date.current.iso8601, to: Date.current.iso8601)
    assert_select "tbody tr", count: 2

    get notification_history_index_path(from: (Date.current - 10).iso8601, to: (Date.current - 5).iso8601)
    assert_select "tbody tr", count: 0
  end

  test "pagina por cursor sin OFFSET" do
    sign_in users(:admin_cl)
    30.times { |i| SurveyReminderNotification.deliver(to: employees(:ana), params: { survey_title: "Encuesta #{i}" }) }

    assert_no_queries_match(/OFFSET/i) { get notification_history_index_path }
    assert_select "tbody tr", count: NotificationHistory::Scope::PER_PAGE
    older = css_select(".pagination a").first["href"]

    get older
    assert_select "tbody tr", count: 32 - NotificationHistory::Scope::PER_PAGE
  end

  test "un cursor manipulado se ignora en vez de provocar un error" do
    sign_in users(:admin_cl)

    get notification_history_index_path(before: "#{Time.current.utc.iso8601}|no-es-un-uuid")
    assert_response :success

    get notification_history_index_path(before: "no-es-una-fecha|#{SecureRandom.uuid}")
    assert_response :success
  end

  test "un rango de más de 90 días muestra el mensaje de soporte y no consulta la BD" do
    sign_in users(:admin_cl)

    assert_no_queries_match(/FROM "?notification_(requests|deliveries|events)"?/) do
      get notification_history_index_path(from: (Date.current - 120).iso8601)
    end

    assert_select ".notice-box", text: "Para consultas de más de 90 días, contacta a soporte."
  end

  test "el detalle muestra la línea de tiempo en la zona de la empresa y no el cuerpo" do
    sign_in users(:admin_cl)
    get notification_history_path(@payslip.id)

    assert_response :success
    assert_select ".timeline li", text: /Notificación registrada/
    assert_select ".timeline li", text: /Enviada al proveedor de correo/
    assert_select ".timeline li", text: /Entregada en la bandeja del colaborador/
    assert_select ".timeline time", text: /#{Time.current.in_time_zone("America/Santiago").strftime('%d-%m-%Y %H:%M')}/
    assert_select "dd", text: "Tu liquidación de septiembre de 2026 está disponible"
    assert_no_match "Ya puedes revisar y descargar", response.body
  end

  test "cada consulta queda registrada en notification_history_accesses" do
    sign_in users(:admin_cl)

    assert_difference -> { NotificationHistoryAccess.count }, 2 do
      get notification_history_index_path(employee: "ana", status: "delivered")
      get notification_history_path(@payslip.id)
    end

    index_access, show_access = NotificationHistoryAccess.order(:id).last(2)
    assert_equal users(:admin_cl), index_access.user
    assert_equal companies(:acme_cl), index_access.company
    assert_equal({ "employee" => "ana", "status" => "delivered" }, index_access.filters)
    assert_equal @payslip.id, show_access.viewed_request_id
  end

  private

  def sign_in(user)
    post dev_session_path, params: { user_id: user.id }
  end
end
