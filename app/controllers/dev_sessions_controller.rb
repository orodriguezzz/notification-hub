# Modo demo: elige el usuario simulado (Current.user)
class DevSessionsController < ApplicationController
  def create
    user = User.find(params.require(:user_id))
    session[:user_id] = user.id
    redirect_to root_path, notice: t("dev_sessions.signed_in", name: user.name)
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: t("dev_sessions.signed_out")
  end
end
