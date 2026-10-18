require "test_helper"
require Rails.root.join("lib/rubocop/cop/notifications/no_deliver_in_controllers")

class NoDeliverInControllersCopTest < ActiveSupport::TestCase
  test "detecta deliver, deliver_many y sent sobre una notificación" do
    offenses = investigate(<<~RUBY)
      class LeaveRequestsController < ApplicationController
        def approve
          LeaveRequestApprovedNotification.deliver(to: employee, params: {})
          BirthdayNotification.deliver_many(to: employees)
          ::BirthdayNotification.sent(to: employee)
        end
      end
    RUBY

    assert_equal 3, offenses.size
    assert_match "servicio de dominio", offenses.first.message
  end

  test "no marca llamadas a servicios ni otros deliver" do
    offenses = investigate(<<~RUBY)
      class LeaveRequestsController < ApplicationController
        def approve
          Leave::ApproveRequest.call(leave_request: leave_request, approver: current_user)
          UserMailer.welcome.deliver_later
          package.deliver
        end
      end
    RUBY

    assert_empty offenses
  end

  test "bin/rubocop la aplica solo en app/controllers" do
    config = RuboCop::ConfigLoader.load_file(Rails.root.join(".rubocop.yml").to_s)
    cop_config = config.for_cop("Notifications/NoDeliverInControllers")

    assert cop_config["Enabled"]
    assert_equal [ "app/controllers/**/*.rb" ], cop_config["Include"]
  end

  private

  def investigate(source)
    processed = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "app/controllers/leave_requests_controller.rb")
    cop = RuboCop::Cop::Notifications::NoDeliverInControllers.new(RuboCop::Config.new({}, "/"))
    RuboCop::Cop::Commissioner.new([ cop ]).investigate(processed).offenses
  end
end
