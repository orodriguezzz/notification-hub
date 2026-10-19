module Notifications
  # Motivos que se guardan en notification_requests.status_reason. Un solo lugar para estos textos:
  # los escriben el despacho, los jobs y el resolver, y el historial los traduce a lenguaje simple.
  module Reasons
    ENTITY_MISSING = "entity_missing".freeze      # el destinatario o un parámetro ya no existe
    EXPIRED = "expired".freeze                    # venció antes de poder enviarse
    PROVIDER_REJECTED = "provider_rejected".freeze # el proveedor rechazó el envío (error definitivo)
    RETRIES_EXHAUSTED = "retries_exhausted".freeze
    RETRYING = "retrying".freeze                  # error transitorio, a la espera del reintento
    RECOVERED = "recovered".freeze                # rescatado tras quedar trabado en processing
    FALLBACK = "fallback".freeze                  # salió por un canal de respaldo
    BOUNCED = "bounced".freeze

    # Anti-spam
    COOLDOWN = "cooldown".freeze
    QUIET_HOURS = "quiet_hours".freeze
    RATE_LIMIT = "rate_limit".freeze
    DIGEST = "digest".freeze                      # postergado para el resumen diario
    DIGESTED = "digested".freeze                  # incluido en un resumen ya enviado

    # Resolver de canales
    OPTED_OUT = "opted_out".freeze
    NO_CONTACT = "no_contact".freeze
    CHANNEL_DISABLED = "channel_disabled".freeze
    NO_CHANNEL = "no_channel".freeze
  end
end
