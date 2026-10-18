# Crítica: debe salir siempre (sin límites, horario de silencio ni opt-out). Validado con producto.
class SignedDocumentCopyNotification < ApplicationNotification
  key      :signed_document_copy
  category :critical
  owner    :documents_team
  recipient :employee

  param :employee,       required: true
  param :document_title, required: true
  param :signed_at,      required: true   # Time

  dedupe_by { |p| [ p.employee.id, p.document_title, p.signed_at.to_i ] }

  content do |p|
    signed_at = p.signed_at.in_time_zone(p.employee.effective_time_zone)
    title  t(".title", title: p.document_title)
    body   t(".body", title: p.document_title, signed_at: I18n.l(signed_at, format: :long))
    action t(".action"), url: routes.root_url
  end

  email do |p|
    subject t(".subject", title: p.document_title)
  end

  preview { { employee: Employee.first, document_title: "Anexo de contrato", signed_at: 2.days.ago } }
end
