# Desuscripción sin login, con token firmado. GET muestra la confirmación; POST desuscribe
# (también lo usan los clientes de correo con List-Unsubscribe-Post, sin token CSRF).
class UnsubscribesController < ApplicationController
  skip_forgery_protection only: :create
  skip_before_action :set_current_user

  before_action :resolve_token

  def show
  end

  def create
    @employee.opt_out!(@category)
    render :done
  end

  private

  def resolve_token
    @employee, @category = Notifications::UnsubscribeToken.resolve(params[:token])
    render :invalid, status: :not_found unless @employee
  end
end
