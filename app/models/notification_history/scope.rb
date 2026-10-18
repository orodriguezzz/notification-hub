module NotificationHistory
  # Punto único de acceso al historial de notificaciones de una empresa cliente.
  # Toda consulta filtra por company_id = user.company_id: un id de otra empresa no se encuentra (404).
  class Scope
    class Forbidden < StandardError; end

    WINDOW = 90.days
    PER_PAGE = 25
    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    Row = Data.define(:request, :employee, :delivery, :status)
    Page = Data.define(:rows, :next_cursor)

    attr_reader :user

    def initialize(user)
      raise Forbidden unless user&.company_admin?

      @user = user
    end

    def company
      user.company
    end

    def zone
      company.zone
    end

    def window_start
      (Time.current.in_time_zone(zone) - WINDOW).beginning_of_day
    end

    # Un rango anterior a la ventana de 90 días no se consulta en PostgreSQL
    def out_of_window?(filters)
      filters.from.present? && zone.local(filters.from.year, filters.from.month, filters.from.day) < window_start
    end

    def page(filters)
      relation = filtered(filters).order(created_at: :desc, id: :desc).limit(PER_PAGE + 1).to_a
      requests = relation.first(PER_PAGE)
      next_cursor = relation.size > PER_PAGE ? cursor_for(requests.last) : nil

      Page.new(rows: rows_for(requests), next_cursor: next_cursor)
    end

    def find(id)
      base.find(id)
    end

    def detail(id)
      request = find(id)
      {
        request: request,
        employee: employees_by_id([ request ])[request.recipient_id],
        deliveries: NotificationDelivery.where(company_id: company.id, request_id: request.id).order(:created_at).to_a,
        events: NotificationEvent.where(request_id: request.id).where.not(event_type: Status::HIDDEN_EVENTS)
                                 .chronological.to_a,
        status: Status.for(request, latest_delivery([ request ])[request.id])
      }
    end

    # Tipos de notificación para el filtro: [nombre legible, key]
    def notification_types
      Notifications::Registry.keys.map { |key| [ Status.notification_name(key), key ] }.sort_by(&:first)
    end

    private

    def base
      NotificationRequest.where(company_id: company.id, created_at: window_start..)
    end

    def filtered(filters)
      relation = base
      if filters.employee.present?
        relation = relation.where(recipient_type: "Employee",
                                  recipient_id: company.employees.search(filters.employee).select(:id))
      end
      relation = relation.where(created_at: day_start(filters.from)..) if filters.from
      relation = relation.where(created_at: ...day_start(filters.to + 1)) if filters.to
      relation = relation.where(notification_key: filters.notification_key) if filters.notification_key.present?
      relation = Status.filter(relation, filters.status) if filters.status.present?
      relation = after_cursor(relation, filters.before) if filters.before.present?
      relation
    end

    def day_start(date)
      zone.local(date.year, date.month, date.day)
    end

    # Paginación por cursor sobre (created_at, id), sin OFFSET
    def cursor_for(request)
      "#{request.created_at.utc.iso8601(6)}|#{request.id}"
    end

    # Un cursor manipulado (id que no es UUID o fecha inválida) se ignora en vez de llegar a PostgreSQL
    def after_cursor(relation, cursor)
      created_at, id = cursor.split("|", 2)
      return relation unless id.to_s.match?(UUID_FORMAT)

      relation.where("(notification_requests.created_at, notification_requests.id) < (?, ?)", Time.iso8601(created_at), id)
    rescue ArgumentError
      relation
    end

    def rows_for(requests)
      employees = employees_by_id(requests)
      deliveries = latest_delivery(requests)

      requests.map do |request|
        delivery = deliveries[request.id]
        Row.new(request: request, employee: employees[request.recipient_id], delivery: delivery,
                status: Status.for(request, delivery))
      end
    end

    def employees_by_id(requests)
      company.employees.where(id: requests.map(&:recipient_id)).index_by(&:id)
    end

    def latest_delivery(requests)
      NotificationDelivery.where(company_id: company.id, request_id: requests.map(&:id))
                          .order(:created_at).index_by(&:request_id)
    end
  end
end
