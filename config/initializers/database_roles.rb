# Roles de escritura y lectura (réplica) sobre ActiveRecord::Base.
#
# Se declara en ActiveRecord::Base y no en ApplicationRecord a propósito: SolidQueue::Record
# hereda de ActiveRecord::Base, así que la cola y los modelos de la app comparten el MISMO pool
# de conexiones. Con un `connects_to` en ApplicationRecord habría dos pools distintos y el
# encolado del DispatchJob quedaría fuera de la transacción del llamador (se rompe el outbox).
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :primary_replica })
end
