module Notifications
  # Origen de un envío: quién, desde qué request o job y desde qué archivo del código
  module Origin
    INTERNAL_PATHS = %w[/lib/notifications/ /app/notifications/].freeze

    module_function

    def capture
      {
        user_id: Current.user&.id,
        request_id: Current.request_id,
        job: Current.job,
        caller: caller_source
      }.compact
    end

    # Primer archivo de app/ fuera de la central (servicio, job o controlador llamador)
    def caller_source
      root = "#{Rails.root}/"
      location = caller_locations.find do |loc|
        path = loc.path.to_s
        path.start_with?("#{root}app/") && INTERNAL_PATHS.none? { |internal| path.include?(internal) }
      end
      return unless location

      "#{location.path.delete_prefix(root)}:#{location.lineno}"
    end
  end
end
