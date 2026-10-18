require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @employee = employees(:ana)
    @token = Notifications::UnsubscribeToken.generate(@employee)
  end

  test "GET muestra la confirmación sin desuscribir" do
    get unsubscribe_path(@token)

    assert_response :success
    assert_select "h1", "Dejar de recibir correos"
    assert_not @employee.reload.opted_out?(:engagement)
  end

  test "POST (one-click) agrega engagement a los opt-outs" do
    post unsubscribe_path(@token)

    assert_response :success
    assert @employee.reload.opted_out?(:engagement)
  end

  test "el alias en español funciona igual" do
    post desuscribir_path(@token)
    assert @employee.reload.opted_out?(:engagement)
  end

  test "un token alterado responde 404" do
    get unsubscribe_path("#{@token}x")
    assert_response :not_found
  end
end
