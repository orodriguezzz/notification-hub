module Notifications
  # Serializa los parámetros para guardarlos en notification_requests.params (jsonb).
  # Los modelos se guardan como GlobalID, igual que los argumentos de Active Job.
  module ParamSerializer
    module_function

    def dump(params)
      ActiveJob::Arguments.serialize([ params.to_h.symbolize_keys ]).first
    end

    # Lanza ActiveJob::DeserializationError si alguna entidad ya no existe
    def load(serialized)
      ActiveJob::Arguments.deserialize([ serialized ]).first.symbolize_keys
    end
  end
end
