require "test_helper"

# Sin transacción de test: cada thread usa su propia conexión y hace commit real
class Notifications::CounterConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ActiveRecord::Base.connection_pool.with_connection { _1.execute("TRUNCATE notification_counters") }
  end

  test "con límite 2 y 10 threads concurrentes, exactamente 2 pasan" do
    gate = Concurrent::CountDownLatch.new(1)

    threads = Array.new(10) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          Notifications::AntiSpam::Counter.increment!(recipient_type: "Employee", recipient_id: 42,
                                                      bucket_date: Date.current, category: "engagement", limit: 2)
        end
      end
    end
    gate.count_down
    results = threads.map(&:value)

    assert_equal 2, results.compact.size
    assert_equal [ 1, 2 ], results.compact.sort
    assert_equal 2, NotificationCounter.sole.count
  end
end
