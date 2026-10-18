require "test_helper"

# Sin transacción de test: cada thread usa su propia conexión y hace commit real
class Notifications::ConcurrentIdempotencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("TRUNCATE notification_requests, notification_idempotency_keys, notification_events, " \
                         "notification_deliveries, solid_queue_jobs CASCADE")
    end
  end

  test "10 threads con la misma clave generan un solo request" do
    employee = employees(:ana)
    company = companies(:acme_cl)
    gate = Concurrent::CountDownLatch.new(1)

    threads = Array.new(10) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          BirthdayNotification.deliver(to: employee, params: { company: company }, idempotency_key: "concurrent-1")
        end
      end
    end
    gate.count_down
    handles = threads.map(&:value)

    assert_equal 1, NotificationRequest.count
    assert_equal 1, dispatch_jobs.count
    assert_equal 1, handles.count(&:accepted?)
    assert_equal 9, handles.count(&:duplicate?)
    assert_equal [ handles.first.id ], handles.map(&:id).uniq
  end
end
