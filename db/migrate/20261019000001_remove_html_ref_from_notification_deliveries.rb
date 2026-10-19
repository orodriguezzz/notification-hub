# html_ref (puntero al HTML archivado en S3) nunca se implementó: el archivo a S3 queda fuera de alcance.
# En una tabla particionada, quitar la columna del padre la quita de todas sus particiones.
class RemoveHtmlRefFromNotificationDeliveries < ActiveRecord::Migration[8.1]
  def change
    remove_column :notification_deliveries, :html_ref, :string
  end
end
