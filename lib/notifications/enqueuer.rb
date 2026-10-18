module Notifications
  # Camino síncrono de `deliver` y `deliver_many`: SOLO escribe en PostgreSQL.
  #
  # Todo ocurre dentro de la transacción del llamador (savepoint con requires_new), así que el
  # registro del envío es atómico con el negocio: si el llamador hace rollback, no queda ni el
  # request ni el job. Nunca llama al proveedor ni lanza errores de entrega.
  class Enqueuer
    BATCH_SIZE = 1_000

    def initialize(definition)
      @definition = definition
    end

    def deliver(to:, params:, idempotency_key: nil)
      instrument(recipients: 1) do
        row = build_row(to, params, idempotency_key, Origin.capture)
        persist([ row ]).first
      end
    end

    def deliver_many(to:, params: {})
      origin = Origin.capture

      instrument(recipients: nil) do
        each_batch(to).flat_map do |recipients|
          persist(recipients.map { |recipient| build_row(recipient, params, nil, origin) })
        end
      end
    end

    private

    def each_batch(recipients, &block)
      return enum_for(:each_batch, recipients) unless block

      if recipients.is_a?(ActiveRecord::Relation)
        recipients.find_in_batches(batch_size: BATCH_SIZE, &block)
      else
        Array(recipients).each_slice(BATCH_SIZE, &block)
      end
    end

    def build_row(to, params, explicit_key, origin)
      normalized = @definition.normalize_params(to, params)
      now = Time.current

      {
        id: SecureRandom.uuid_v7,
        company_id: company_id_for(to),
        notification_key: @definition.notification_key.to_s,
        notification_version: @definition.version,
        category: @definition.category.to_s,
        recipient_type: to.class.polymorphic_name,
        recipient_id: to.id,
        params: ParamSerializer.dump(normalized),
        origin: origin,
        idempotency_key: explicit_key.presence&.to_s || @definition.dedupe_key(normalized) || SecureRandom.uuid,
        status: "accepted",
        expires_at: @definition.expires_in && now + @definition.expires_in,
        created_at: now,
        updated_at: now
      }
    end

    def company_id_for(recipient)
      company_id = recipient.try(:company_id)
      raise InvalidParamsError, "#{@definition.name}: el destinatario no pertenece a una empresa" unless company_id

      company_id
    end

    def persist(rows)
      NotificationRequest.transaction(requires_new: true) do
        inserted_ids = insert_idempotency_keys(rows)
        accepted, duplicates = rows.partition { |row| inserted_ids.include?(row[:id]) }

        if accepted.any?
          NotificationRequest.insert_all!(accepted)
          NotificationEvent.insert_all!(accepted.map { |row| enqueued_event(row) })
          enqueue_dispatch(accepted)
        end

        existing_ids = existing_request_ids(duplicates)

        rows.map do |row|
          if inserted_ids.include?(row[:id])
            DeliveryHandle.new(id: row[:id], status: :accepted)
          else
            DeliveryHandle.new(id: existing_ids.fetch(identity(row)), status: :duplicate)
          end
        end
      end
    end

    # INSERT ... ON CONFLICT DO NOTHING RETURNING request_id: devuelve solo los ids insertados
    def insert_idempotency_keys(rows)
      key_rows = rows.map do |row|
        {
          notification_key: row[:notification_key],
          recipient_type: row[:recipient_type],
          recipient_id: row[:recipient_id],
          idempotency_key: row[:idempotency_key],
          request_id: row[:id],
          expires_at: row[:created_at] + NotificationIdempotencyKey::WINDOW,
          created_at: row[:created_at],
          updated_at: row[:created_at]
        }
      end

      NotificationIdempotencyKey
        .insert_all(key_rows, unique_by: :idx_notification_idempotency_unique, returning: %w[request_id])
        .rows.flatten.to_set
    end

    def existing_request_ids(duplicates)
      return {} if duplicates.empty?

      NotificationIdempotencyKey
        .where(notification_key: duplicates.first[:notification_key])
        .where(recipient_type: duplicates.map { _1[:recipient_type] }.uniq,
               recipient_id: duplicates.map { _1[:recipient_id] }.uniq,
               idempotency_key: duplicates.map { _1[:idempotency_key] }.uniq)
        .pluck(:recipient_type, :recipient_id, :idempotency_key, :request_id)
        .to_h { |type, id, key, request_id| [ [ type, id, key ], request_id ] }
    end

    def identity(row)
      [ row[:recipient_type], row[:recipient_id], row[:idempotency_key] ]
    end

    def enqueued_event(row)
      { request_id: row[:id], event_type: "enqueued", payload: {}, occurred_at: row[:created_at], created_at: row[:created_at] }
    end

    # El job se inserta en solid_queue_jobs dentro de la misma transacción (misma BD, misma conexión)
    def enqueue_dispatch(rows)
      queue = Notifications.queue_for(@definition.category)
      jobs = rows.map { |row| DispatchJob.new(row[:id]).set(queue: queue) }
      ActiveJob.perform_all_later(jobs)

      failed = jobs.reject(&:successfully_enqueued?)
      raise Error, "No se pudieron encolar #{failed.size} DispatchJob" if failed.any?
    end

    def instrument(recipients:)
      payload = {
        notification_key: @definition.notification_key, category: @definition.category, owner: @definition.owner
      }

      ActiveSupport::Notifications.instrument("deliver.notifications", payload) do
        result = yield
        handles = Array(result)
        payload[:recipients] = recipients || handles.size
        payload[:accepted] = handles.count(&:accepted?)
        payload[:duplicates] = handles.count(&:duplicate?)
        payload[:status] = handles.first&.status if recipients == 1
        result
      end
    end
  end
end
