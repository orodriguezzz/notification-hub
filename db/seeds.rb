# Datos de ejemplo: 2 empresas (Chile y México), 50 colaboradores, un administrador y un
# miembro por empresa, y notificaciones ya despachadas para ver el historial.
# Es idempotente: se puede correr varias veces (las notificaciones se deduplican).
#
# Los emails usan dominios .example (reservados, nunca entregables). Con DEMO_RECIPIENT_EMAIL, la primera
# colaboradora de Acme Chile usa ese correo: es la única que puede recibir correos reales en la demo.

FIRST_NAMES = %w[Ana Bruno Carla Diego Elena Felipe Gabriela Hugo Isabel Javier Karina Luis María Nicolás
                 Olivia Pablo Rocío Sergio Tamara Ulises Valentina Walter Ximena Yolanda Zacarías].freeze
LAST_NAMES = %w[Rojas Soto Hernández Muñoz García López Pérez Silva Torres Flores Díaz Morales Castro Vargas].freeze

companies = [
  { name: "Acme Chile", country: "CL", time_zone: "America/Santiago", domain: "acme-cl.example", admin: "Paula Fuentes" },
  { name: "Globex México", country: "MX", time_zone: "America/Mexico_City", domain: "globex-mx.example", admin: "Lucía Ramírez" }
]

companies.each_with_index do |attrs, company_index|
  company = Company.find_or_create_by!(name: attrs[:name]) do |c|
    c.country = attrs[:country]
    c.time_zone = attrs[:time_zone]
  end

  User.find_or_create_by!(email: "admin@#{attrs[:domain]}") do |u|
    u.company = company
    u.name = attrs[:admin]
    u.role = "company_admin"
  end
  User.find_or_create_by!(email: "miembro@#{attrs[:domain]}") do |u|
    u.company = company
    u.name = "Miembro #{attrs[:name]}"
    u.role = "member"
  end

  25.times do |i|
    first_name = FIRST_NAMES[i]
    last_name = LAST_NAMES[(i + company_index * 3) % LAST_NAMES.size]
    email = "#{I18n.transliterate(first_name).downcase}.#{I18n.transliterate(last_name).downcase}@#{attrs[:domain]}"

    Employee.find_or_create_by!(company: company, email: email) do |e|
      e.first_name = first_name
      e.last_name = last_name
      e.phone = "+#{company_index.zero? ? '569' : '5255'}#{format('%08d', i + 1)}"
      e.birth_date = Date.new(1980 + i, (i % 12) + 1, (i % 27) + 1)
      # Un colaborador desuscrito de engagement por empresa
      e.notification_opt_outs = i == 24 ? [ "engagement" ] : []
    end
  end
end

if (demo_email = ENV["DEMO_RECIPIENT_EMAIL"].presence)
  Company.find_by!(name: "Acme Chile").employees.order(:id).first.update!(email: demo_email)
end

# Notificaciones de ejemplo, despachadas en el momento con el adaptador de prueba:
# llenan el historial sin enviar correos reales, aunque la app use SendGrid.
Notifications::Channels::Registry.register(:email, renderer: Notifications::Channels::Email::Renderer,
                                                   adapter: Notifications::Channels::Email::TestAdapter)
period = Date.current.prev_month.beginning_of_month
handles = Company.includes(:employees).flat_map do |company|
  employees = company.employees.order(:id).to_a

  PayslipAvailableNotification.deliver_many(to: employees.first(10), params: { period: period }) +
    BirthdayNotification.deliver_many(to: [ employees[2], employees.last ], params: { company: company }) +
    [
      LeaveRequestApprovedNotification.deliver(
        to: employees[1], params: { starts_on: Date.current + 20, ends_on: Date.current + 30, approver_name: "Administración" }
      ),
      SignedDocumentCopyNotification.deliver(
        to: employees[0], params: { document_title: "Anexo de contrato #{Date.current.year}", signed_at: Time.zone.parse("#{Date.current} 09:00") }
      )
    ]
end

handles.select(&:accepted?).each { |handle| Notifications::Dispatcher.call(handle.id) }

puts "Seeds: #{Company.count} empresas, #{Employee.count} colaboradores, #{User.count} usuarios, " \
     "#{NotificationRequest.count} notificaciones (#{NotificationRequest.group(:status).count})."
