module Notifications
  # Tipos de destinatario permitidos. recipient_type se guarda en la base de datos: solo se convierte
  # en clase si está en esta lista, nunca con constantize sobre un dato arbitrario.
  module Recipients
    TYPES = %w[Employee].freeze

    module_function

    def allowed?(type)
      TYPES.include?(type.to_s)
    end

    # Clase del destinatario, o nil si el tipo no está permitido
    def class_for(type)
      type.to_s.constantize if allowed?(type)
    end

    def find(type, id)
      class_for(type)&.find_by(id: id)
    end
  end
end
