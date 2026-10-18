require "test_helper"

class MaintenanceJobsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "PartitionMaintenanceJob crea las particiones de los meses siguientes y es idempotente" do
    future = Date.current >> 6
    travel_to future.to_time

    created = Notifications::PartitionMaintenanceJob.perform_now

    expected = Notifications::Partitions::TABLES.flat_map do |table|
      (0..2).map { |i| Notifications::Partitions.partition_name(table, future.beginning_of_month >> i) }
    end
    assert_equal expected.sort, created.sort
    expected.each { |name| assert NotificationRequest.connection.table_exists?(name), "falta #{name}" }

    assert_empty Notifications::PartitionMaintenanceJob.perform_now
  end

  test "PurgeJob borra claves vencidas y contadores antiguos, y lista particiones archivables" do
    handle = BirthdayNotification.deliver(to: employees(:ana), params: { company: companies(:acme_cl) })
    now = 31.days.from_now
    NotificationCounter.create!(recipient_type: "Employee", recipient_id: 1, bucket_date: (now - 10.days).to_date,
                                category: "engagement", count: 1)
    NotificationCounter.create!(recipient_type: "Employee", recipient_id: 1, bucket_date: now.to_date,
                                category: "engagement", count: 1)

    result = Notifications::PurgeJob.perform_now(now: now)

    assert_equal 1, result[:idempotency_keys]
    assert_not NotificationIdempotencyKey.exists?(request_id: handle.id)
    assert_equal 1, result[:counters]
    assert_equal 1, NotificationCounter.count
    assert_kind_of Array, result[:archivable_partitions]
  end
end
