Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # --- Historial para el administrador de cada empresa (URLs públicas en español) -------------
  root "notification_history#index"
  get "historial-notificaciones", to: "notification_history#index", as: :notification_history_index
  get "historial-notificaciones/:id", to: "notification_history#show", as: :notification_history

  # --- Desuscripción sin login (token firmado). /desuscribir es el alias en español ------------
  %w[unsubscribe desuscribir].each do |path|
    get "#{path}/:token", to: "unsubscribes#show", as: (path == "unsubscribe" ? :unsubscribe : :desuscribir)
    post "#{path}/:token", to: "unsubscribes#create"
  end

  # --- Event Webhook de SendGrid -------------------------------------------------------------
  namespace :webhooks do
    post "sendgrid", to: "sendgrid#create"
  end

  # --- Modo demo (siempre en local; en servidor con DEMO_MODE=true) -----------------------------
  if Rails.configuration.x.demo_mode
    resource :dev_session, only: %i[create destroy], path: "dev/session"

    # Swagger UI para revisar los endpoints HTTP (docs/openapi.yaml)
    get "api-docs", to: "api_docs#show", as: :api_docs
    get "api-docs/openapi.yaml", to: "api_docs#spec", as: :api_docs_spec
  end
end
