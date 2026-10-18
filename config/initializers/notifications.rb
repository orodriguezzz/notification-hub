# Central de notificaciones: canales, política y observabilidad.

Rails.application.config.to_prepare do
  # Canales registrados. Agregar un canal = renderer + adaptador + registro + una línea en la política.
  email_adapters = {
    sendgrid: Notifications::Channels::Email::SendgridAdapter,
    test: Notifications::Channels::Email::TestAdapter
  }
  email_adapter = Rails.configuration.x.notifications.email_adapter
  Notifications::Channels::Registry.register(
    :email,
    renderer: Notifications::Channels::Email::Renderer,
    adapter: email_adapters.fetch(email_adapter) { raise "NOTIFICATIONS_EMAIL_ADAPTER inválido: #{email_adapter}" }
  )

  # Política central (config/notifications/channel_policy.rb), validada al arrancar
  Notifications::Policy.load_default!
end

# URLs absolutas en los correos (acciones y desuscripción)
Rails.application.routes.default_url_options = { host: Rails.configuration.x.app_host }

# Logs JSON estructurados de cada evento de la central (CloudWatch queda fuera de alcance local)
ActiveSupport::Notifications.subscribe(/\.notifications\z/) do |event|
  payload = event.payload
  entry = {
    event: event.name,
    notification_key: payload[:notification_key],
    category: payload[:category],
    owner: payload[:owner],
    channel: payload[:channel],
    status: payload[:status],
    reason: payload[:reason],
    request_id: payload[:request_id],
    duration_ms: event.duration.round(2)
  }.compact

  Rails.logger.info(entry.to_json)
end
