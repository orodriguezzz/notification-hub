module Notifications
  # Tarea recurrente: rescata requests que quedaron en processing porque el worker se cayó a mitad
  # del despacho (deploy, reinicio de la instancia). Solid Queue vuelve a ejecutar el job, pero el
  # Dispatcher solo toma requests accepted o deferred, así que sin esta tarea quedarían trancados.
  #
  #   - Despacho normal -> vuelve a accepted y se encola un DispatchJob en la misma transacción.
  #     Si había una entrega pendiente, el Dispatcher la reenvía (at-least-once).
  #   - Digest -> vuelve a deferred; DigestJob lo toma en su próxima corrida.
  class RecoverStaleJob < ApplicationJob
    queue_as :default

    # Un despacho normal tarda segundos; 15 minutos sin cambios significa que el worker murió
    STALE_AFTER = 15.minutes

    def perform(now: Time.current)
      threshold = now - STALE_AFTER
      recovered = NotificationRequest.processing.where(updated_at: ...threshold).pluck(:id).count do |id|
        recover(id, threshold)
      end

      Rails.logger.info({ event: "recover_stale.notifications", recovered: recovered }.to_json) if recovered.positive?
      recovered
    end

    private

    # Devuelve true si el request seguía trancado y se recuperó
    def recover(id, threshold)
      NotificationRequest.transaction do
        request = NotificationRequest.lock("FOR UPDATE SKIP LOCKED").processing
                                     .where(updated_at: ...threshold).find_by(id: id)
        next false unless request

        if request.status_reason == Reasons::DIGEST
          request.update!(status: "deferred")
        else
          request.update!(status: "accepted", status_reason: Reasons::RECOVERED)
          DispatchJob.set(queue: Notifications.queue_for(request.category)).perform_later(request.id)
        end
        NotificationEvent.record!(:recovered, request: request, payload: { stale_since: request.updated_at_before_last_save })
        true
      end
    end
  end
end
