# Prueba de carga simple de la central.
#
#   bin/rails runner script/load_test.rb
#
# Variables opcionales:
#   TOTAL=50000        requests a registrar con deliver_many
#   BATCH=1000         tamaño de cada lote
#   DISPATCH=5000      cuántos de esos requests despachar
#   THREADS=5          threads de despacho (requiere RAILS_MAX_THREADS >= THREADS)
#   CLEANUP=1          al terminar, vacía las tablas de la central (incluye notification_events)
#
# Usa el TestAdapter (sin red). Corre en development: no apuntes esto a producción.
abort "Este script no corre en producción" if Rails.env.production?

def measure
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

# Se mide la central, no el instrumental de development (backtrace y tags por query, logs en debug)
Rails.logger.level = :warn
ActiveRecord.verbose_query_logs = false
ActiveRecord.query_transformers.delete(ActiveRecord::QueryLogs)

total = Integer(ENV.fetch("TOTAL", 50_000))
batch = Integer(ENV.fetch("BATCH", 1_000))
dispatch_count = Integer(ENV.fetch("DISPATCH", 5_000))
threads = Integer(ENV.fetch("THREADS", 5))

Notifications::Channels::Registry.register(:email, renderer: Notifications::Channels::Email::Renderer,
                                                   adapter: Notifications::Channels::Email::TestAdapter)
employees = Employee.where.not(email: nil).to_a
abort "No hay colaboradores: corre bin/rails db:seed" if employees.empty?

started_at = Time.current
title = "Carga #{started_at.to_i}"
puts "== Registro: #{total} requests en lotes de #{batch} (SurveyReminderNotification, sin dedupe)"

accepted_ids = []
elapsed = measure do
  (total / batch).times do
    recipients = Array.new(batch) { |i| employees[i % employees.size] }
    accepted_ids.concat(SurveyReminderNotification.deliver_many(to: recipients, params: { survey_title: title })
                                                  .select(&:accepted?).map(&:id))
  end
end
puts format("   %d requests en %.2fs -> %.0f requests/s (%.0f/h)", accepted_ids.size, elapsed,
            accepted_ids.size / elapsed, accepted_ids.size / elapsed * 3600)

sample = accepted_ids.first(dispatch_count)
puts "== Despacho: #{sample.size} requests con #{threads} threads (TestAdapter)"
queue = Queue.new
sample.each { queue << _1 }
threads.times { queue << nil }

elapsed = measure do
  Array.new(threads) do
    Thread.new do
      Rails.application.executor.wrap do
        while (id = queue.pop)
          Notifications::Dispatcher.call(id)
        end
      end
    end
  end.each(&:join)
end
statuses = NotificationRequest.where(id: sample).group(:status).count
puts format("   %d despachos en %.2fs -> %.0f despachos/s (%.0f/h)", sample.size, elapsed,
            sample.size / elapsed, sample.size / elapsed * 3600)
puts "   estados: #{statuses}"
puts "   correos en memoria: #{Notifications::Channels::Email::TestAdapter.deliveries.size}"

# Los jobs encolados por la prueba no deben quedar para el worker
removed = SolidQueue::Job.where(class_name: "Notifications::DispatchJob", created_at: started_at..).delete_all
puts "== Se eliminaron #{removed} DispatchJob encolados por la prueba"

if ENV["CLEANUP"] == "1"
  ActiveRecord::Base.lease_connection.execute(
    "TRUNCATE notification_requests, notification_deliveries, notification_events, " \
    "notification_idempotency_keys, notification_counters"
  )
  puts "== Tablas de la central vaciadas (CLEANUP=1)"
else
  puts "== Los datos de la prueba quedan en la base (usa CLEANUP=1 para vaciar las tablas de la central)"
end
