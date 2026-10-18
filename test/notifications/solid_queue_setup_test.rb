require "test_helper"

# Solid Queue vive en la base principal: encolar es atómico con el negocio
class Notifications::SolidQueueSetupTest < ActiveSupport::TestCase
  test "SolidQueue::Job usa la misma conexión que NotificationRequest" do
    assert_same NotificationRequest.connection_pool, SolidQueue::Job.connection_pool
    assert_same NotificationRequest.lease_connection, SolidQueue::Job.lease_connection
  end

  test "el adaptador de Active Job es Solid Queue" do
    assert_equal "SolidQueueAdapter", ActiveJob::Base.queue_adapter.class.name.demodulize
  end

  test "DispatchJob se encola dentro de la transacción del llamador" do
    assert_equal false, Notifications::DispatchJob.enqueue_after_transaction_commit
  end

  test "no existe una base de datos queue separada" do
    configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, include_hidden: true).map(&:name)
    assert_not_includes configs, "queue"
  end
end
