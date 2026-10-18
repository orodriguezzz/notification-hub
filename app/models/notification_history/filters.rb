module NotificationHistory
  # Filtros del historial, leídos desde los parámetros de la URL
  Filters = Data.define(:employee, :from, :to, :notification_key, :status, :before) do
    def self.from_params(params)
      new(
        employee: params[:employee].to_s.strip.presence,
        from: parse_date(params[:from]),
        to: parse_date(params[:to]),
        notification_key: params[:notification_key].presence,
        status: params[:status].presence_in(Status::FILTERS.keys),
        before: params[:before].presence
      )
    end

    def self.parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    # Lo que se guarda en la meta-auditoría
    def to_audit
      to_h.except(:before).compact.transform_values(&:to_s)
    end

    def to_query
      to_h.except(:before).compact.transform_values(&:to_s)
    end
  end
end
