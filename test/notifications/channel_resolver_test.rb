require "test_helper"

class Notifications::ChannelResolverTest < ActiveSupport::TestCase
  setup do
    @resolver = Notifications::ChannelResolver.new
    @company = companies(:acme_cl)
  end

  test "canal disponible cuando la política lo incluye y el destinatario tiene email" do
    resolution = resolve(:operational, employees(:ana))

    assert_equal [ :email ], resolution.channels
    assert_equal({ email: "available" }, resolution.reasons)
  end

  test "canal deshabilitado globalmente se descarta" do
    NotificationChannelSetting.create!(company_id: nil, channel: "email", enabled: false)

    resolution = resolve(:critical, employees(:ana))

    assert resolution.empty?
    assert_equal "disabled_global", resolution.reasons[:email]
    assert_equal "channel_disabled", resolution.skip_reason
  end

  test "canal deshabilitado para la empresa se descarta solo en esa empresa" do
    NotificationChannelSetting.create!(company: @company, channel: "email", enabled: false)

    assert_equal "disabled_company", resolve(:operational, employees(:ana)).reasons[:email]
    assert_equal [ :email ], @resolver.call(category: :operational, company_id: companies(:globex_mx).id,
                                            recipient: employees(:carla)).channels
  end

  test "un registro habilitado no bloquea" do
    NotificationChannelSetting.create!(company_id: nil, channel: "email", enabled: true)
    assert_equal [ :email ], resolve(:operational, employees(:ana)).channels
  end

  test "destinatario sin email no tiene canal" do
    resolution = resolve(:operational, employees(:bruno))

    assert resolution.empty?
    assert_equal "no_contact", resolution.skip_reason
  end

  test "el opt-out se respeta para engagement" do
    resolution = resolve(:engagement, employees(:diego))

    assert resolution.empty?
    assert_equal "opted_out", resolution.skip_reason
  end

  test "el opt-out no aplica a las críticas" do
    employees(:diego).update!(notification_opt_outs: %w[engagement critical])

    assert_equal [ :email ], resolve(:critical, employees(:diego)).channels
  end

  private

  def resolve(category, employee)
    @resolver.call(category: category, company_id: employee.company_id, recipient: employee)
  end
end
