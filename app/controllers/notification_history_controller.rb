# Historial de notificaciones para el administrador de cada empresa cliente.
# Todas las lecturas pasan por NotificationHistory::Scope y van al rol de réplica.
class NotificationHistoryController < ApplicationController
  before_action :require_user!
  before_action :set_scope

  rescue_from NotificationHistory::Scope::Forbidden do
    render :forbidden, status: :forbidden
  end

  def index
    @filters = NotificationHistory::Filters.from_params(params)
    record_access(filters: @filters.to_audit)

    if @scope.out_of_window?(@filters)
      @out_of_window = true
    else
      @page = reading { @scope.page(@filters) }
    end
    @notification_types = @scope.notification_types
  end

  def show
    record_access(filters: {}, viewed_request_id: params[:id])
    @detail = reading { @scope.detail(params[:id]) }
  end

  private

  def set_scope
    @scope = NotificationHistory::Scope.new(current_user)
  end

  def reading(&block)
    ActiveRecord::Base.connected_to(role: :reading, &block)
  end

  # Meta-auditoría: quién consultó, con qué filtros y cuándo
  def record_access(filters:, viewed_request_id: nil)
    NotificationHistoryAccess.create!(company: current_user.company, user: current_user,
                                      filters: filters, viewed_request_id: viewed_request_id)
  end
end
