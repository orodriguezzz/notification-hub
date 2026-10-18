require "test_helper"

class ApiDocsControllerTest < ActionDispatch::IntegrationTest
  SPEC = YAML.safe_load_file(Rails.root.join("docs/openapi.yaml"))

  test "muestra Swagger UI y entrega el contrato" do
    get api_docs_path
    assert_response :success
    assert_includes response.body, "SwaggerUIBundle"

    get api_docs_spec_path
    assert_response :success
    assert_equal "3.1.0", YAML.safe_load(response.body)["openapi"]
  end

  test "cada ruta y método del contrato existe en la aplicación" do
    SPEC["paths"].each do |path, operations|
      concrete = path.gsub(/\{[^}]+\}/, "abc123")

      operations.each_key do |method|
        route = Rails.application.routes.recognize_path(concrete, method: method.to_sym)
        assert route[:controller].present?, "#{method.upcase} #{path} no existe"
      rescue ActionController::RoutingError
        flunk "#{method.upcase} #{path} no existe en config/routes.rb"
      end
    end
  end

  test "los tipos de notificación del contrato coinciden con el registro" do
    keys = SPEC.dig("paths", "/historial-notificaciones", "get", "parameters")
               .find { _1["name"] == "notification_key" }.dig("schema", "enum")
    app_keys = Notifications::Registry.all
                                      .select { Object.const_source_location(_1.name).first.include?("/app/notifications/") }
                                      .map { _1.notification_key.to_s }

    assert_equal app_keys.sort, keys.sort
  end

  test "los estados del contrato coinciden con los filtros del historial" do
    assert_equal NotificationHistory::Status::FILTERS.keys, SPEC.dig("components", "schemas", "StatusFilter", "enum")
  end
end
