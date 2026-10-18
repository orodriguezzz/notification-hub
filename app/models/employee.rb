# Destinatario de las notificaciones
class Employee < ApplicationRecord
  belongs_to :company

  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("employees.first_name ILIKE :q OR employees.last_name ILIKE :q OR employees.email ILIKE :q " \
          "OR (employees.first_name || ' ' || employees.last_name) ILIKE :q", q: pattern)
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  # Zona horaria efectiva: la del colaborador o, si falta, la de su empresa
  def effective_time_zone
    ActiveSupport::TimeZone[time_zone.presence || company.time_zone]
  end

  def opted_out?(category)
    notification_opt_outs.include?(category.to_s)
  end

  # Agrega la categoría a las desactivadas, de forma segura ante escrituras concurrentes
  def opt_out!(category)
    with_lock do
      update!(notification_opt_outs: (notification_opt_outs | [ category.to_s ]))
    end
  end
end
