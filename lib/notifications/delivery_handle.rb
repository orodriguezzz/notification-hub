module Notifications
  # Resultado de `deliver`: el id del request y si fue aceptado o era un duplicado
  DeliveryHandle = Data.define(:id, :status) do
    def accepted?
      status == :accepted
    end

    def duplicate?
      status == :duplicate
    end
  end
end
