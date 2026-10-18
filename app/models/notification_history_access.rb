# Meta-auditoría: quién consultó el historial, con qué filtros y cuándo
class NotificationHistoryAccess < ApplicationRecord
  belongs_to :company
  belongs_to :user
end
