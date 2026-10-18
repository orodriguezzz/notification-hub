# Contexto de la ejecución actual. La central lo usa para registrar el origen de cada envío.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_id, :job
end
