# Política central de canales (D4) y anti-spam (D7).
# Los equipos NO eligen canales: declaran `category` en su notificación y esta política decide.
# Agregar un canal = renderer + adaptador + registro + una línea aquí.
Notifications::Policy.define do
  category :critical do
    strategy :fallback          # primer canal disponible; si falla de forma definitiva, el siguiente
    channels :email             # futuro: :email, :sms
    bypass_preferences!
    bypass_rate_limit!
  end

  category :operational do
    strategy :first_available
    channels :email
  end

  category :engagement do
    strategy :first_available
    channels :email
  end

  rate_limit :operational, max: 5, per: :day
  rate_limit :engagement,  max: 2, per: :day, overflow: :digest
  quiet_hours from: "21:00", to: "08:00", except: :critical
  shadow_mode ENV.fetch("NOTIFICATIONS_SHADOW_MODE", "true") == "true"
end
