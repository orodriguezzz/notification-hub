# Usuario del cliente (consulta el historial). La autenticación real queda fuera de alcance.
class User < ApplicationRecord
  ROLES = %w[company_admin member].freeze

  belongs_to :company

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  def company_admin?
    role == "company_admin"
  end
end
