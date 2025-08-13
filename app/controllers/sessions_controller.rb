class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params.dig(:session, :email))
    if user&.authenticate(params.dig(:session, :password))
      if user.totp_enabled?
        session[:pre_2fa_user_id] = user.id
        redirect_to two_factor_verify_path, notice: "Enter your authentication code to complete sign in."
      else
        session[:user_id] = user.id
        redirect_to root_path, notice: "Signed in successfully." 
      end
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    session.delete(:pre_2fa_user_id)
    redirect_to login_path, notice: "Signed out successfully."
  end
end