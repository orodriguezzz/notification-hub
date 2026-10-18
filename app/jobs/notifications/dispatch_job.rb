module Notifications
  # Despacha un request de notificación (ver Notifications::Dispatcher)
  class DispatchJob < ApplicationJob
    queue_as :default

    # El job se inserta DENTRO de la transacción del llamador: como Solid Queue vive en la misma
    # base de datos, encolar es atómico con el negocio (outbox transaccional).
    self.enqueue_after_transaction_commit = false

    retry_on Notifications::TransientDeliveryError, wait: :polynomially_longer, attempts: 8 do |job, error|
      Notifications::Dispatcher.new(job.arguments.first).give_up(error)
    end

    def perform(request_id)
      Notifications::Dispatcher.call(request_id)
    end
  end
end
