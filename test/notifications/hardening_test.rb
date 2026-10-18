require "test_helper"

# Endurecimiento: categorías en un solo lugar y lista permitida de destinatarios
class Notifications::HardeningTest < ActiveSupport::TestCase
  test "cada categoría de la lista única tiene cola y reglas en la política" do
    Notifications.categories.each do |category|
      assert Notifications.queue_for(category).present?, "falta la cola de #{category}"
      assert_equal category, Notifications.policy.rule_for(category).name
    end
  end

  test "la política falla al cargar si no define una categoría de la lista" do
    policy = Notifications.policy.deep_copy
    policy.rules.delete(:engagement)

    error = assert_raises(Notifications::DefinitionError) { policy.validate! }
    assert_match "engagement", error.message
  end

  test "solo convierte en clase los tipos de destinatario permitidos" do
    assert_equal Employee, Notifications::Recipients.class_for("Employee")
    assert_nil Notifications::Recipients.class_for("Kernel")
    assert_nil Notifications::Recipients.find("User", users(:admin_cl).id)
    assert_equal employees(:ana), Notifications::Recipients.find("Employee", employees(:ana).id)
  end

  test "un request con un tipo de destinatario no permitido no instancia esa clase" do
    request = NotificationRequest.new(recipient_type: "Kernel", recipient_id: 1)
    assert_nil request.recipient
  end

  test "deliver rechaza un destinatario de un tipo no permitido" do
    error = assert_raises(Notifications::InvalidParamsError) do
      PayslipAvailableNotification.deliver(to: users(:admin_cl), params: { period: Date.new(2026, 9, 1) })
    end
    assert_match "destinatario no permitido", error.message
  end
end
