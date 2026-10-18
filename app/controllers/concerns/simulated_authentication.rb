# La autenticación real queda fuera de alcance: Current.user se toma de la sesión,
# que en local se elige con el selector de usuario (DevSessionsController).
module SimulatedAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    helper_method :current_user, :selectable_users
  end

  private

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_user
    Current.user
  end

  def selectable_users
    return User.none unless Rails.configuration.x.demo_mode

    User.includes(:company).order(:company_id, :role, :name)
  end

  def require_user!
    render "shared/sign_in_required", status: :unauthorized unless current_user
  end
end
