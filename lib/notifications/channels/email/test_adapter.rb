module Notifications
  module Channels
    module Email
      # Guarda los mensajes en memoria (TestAdapter.deliveries). Usado en test y, opcionalmente, en development.
      class TestAdapter < BaseAdapter
        @deliveries = []
        @failures = []
        @mutex = Mutex.new

        class << self
          def deliveries
            @mutex.synchronize { @deliveries.dup }
          end

          def clear!
            @mutex.synchronize do
              @deliveries.clear
              @failures.clear
            end
          end

          # Hace fallar las próximas entregas con el error indicado (para tests)
          def fail_next!(error_class, message = "Falla simulada", times: 1)
            @mutex.synchronize { times.times { @failures << error_class.new(message) } }
          end

          def record(entry)
            @mutex.synchronize do
              failure = @failures.shift
              raise failure if failure

              @deliveries << entry
            end
          end
        end

        def provider_name = "test"

        def deliver(message:, delivery:)
          provider_message_id = "test-#{SecureRandom.hex(8)}"
          self.class.record(
            to: delivery.address,
            subject: message.subject,
            html: message.html,
            text: message.text,
            headers: unsubscribe_headers(delivery),
            delivery_id: delivery.id,
            request_id: delivery.request_id,
            notification_key: delivery.notification_key,
            category: delivery.category,
            provider_message_id: provider_message_id
          )
          provider_message_id
        end
      end
    end
  end
end
