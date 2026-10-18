# Envía una notificación de cada categoría a un colaborador, por el flujo real:
# deliver -> Solid Queue -> despacho -> SendGrid (o el adaptador configurado) -> historial.
#
#   bin/rails runner script/demo_send.rb tu@correo.com
#
# El colaborador se busca por email (por defecto, DEMO_RECIPIENT_EMAIL).
email = ARGV.first.presence || ENV["DEMO_RECIPIENT_EMAIL"].presence
abort "Indica el email del colaborador: bin/rails runner script/demo_send.rb tu@correo.com" unless email

employee = Employee.find_by(email: email)
abort "No hay un colaborador con el email #{email} (corre los seeds con DEMO_RECIPIENT_EMAIL)" unless employee

stamp = Time.current
handles = {
  "Crítica (copia de documento firmado)" => SignedDocumentCopyNotification.deliver(
    to: employee, params: { document_title: "Anexo de contrato (demo #{stamp.strftime('%H:%M:%S')})", signed_at: stamp }
  ),
  "Operativa (liquidación disponible)" => PayslipAvailableNotification.deliver(
    to: employee, params: { period: stamp.to_date.beginning_of_month }, idempotency_key: "demo-#{stamp.to_i}"
  ),
  "Relacionamiento (recordatorio de encuesta)" => SurveyReminderNotification.deliver(
    to: employee, params: { survey_title: "Clima laboral (demo)" }
  )
}

puts "Notificaciones registradas para #{employee.full_name} <#{email}>:"
handles.each { |label, handle| puts "  #{label}: #{handle.status} #{handle.id}" }
puts "Solid Queue las despacha en segundos; revisa el historial como administrador de #{employee.company.name}."
