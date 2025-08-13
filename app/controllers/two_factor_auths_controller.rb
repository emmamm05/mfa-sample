require "base64"

class TwoFactorAuthsController < ApplicationController
  before_action :require_login, only: [ :setup, :activate, :destroy, :backup_codes, :regenerate_backup_codes ]

  # Step shown after password login when 2FA is enabled
  def new
    if session[:pre_2fa_user_id].blank?
      redirect_to login_path, alert: "Please login first."
    end
  end

  def create
    user = User.find_by(id: session[:pre_2fa_user_id])
    unless user
      redirect_to login_path, alert: "Session expired. Please login again." and return
    end

    code = params[:code]

    if user.verify_totp(code) || user.consume_backup_code!(code)
      # Complete login
      session.delete(:pre_2fa_user_id)
      session[:user_id] = user.id
      notice = "Signed in successfully."
      notice += " Used a backup code; remember to regenerate a new set." unless user.verify_totp(code)
      redirect_to root_path, notice: notice
    else
      flash.now[:alert] = "Invalid code. Please try again."
      render :new, status: :unprocessable_content
    end
  end

  # Setup page to enable TOTP for logged-in users
  def setup
    @user = current_user
    if @user.totp_secret.blank?
      @user.generate_totp_secret!
      @user.save!
    end
    @otpauth_url = @user.provisioning_uri(issuer: app_issuer)
    @qr_data_uri = qr_png_data_uri(@otpauth_url)
  end

  # Confirm code and enable
  def activate
    @user = current_user
    if @user.verify_totp(params[:code])
      @user.enable_totp!
      @backup_codes = @user.generate_backup_codes!
      session[:last_generated_backup_codes] = @backup_codes
      redirect_to two_factor_backup_codes_path, notice: "Two-factor authentication enabled. Save your backup codes."
    else
      flash.now[:alert] = "Invalid code. Please try again."
      @otpauth_url = @user.provisioning_uri(issuer: app_issuer)
      @qr_data_uri = qr_png_data_uri(@otpauth_url)
      render :setup, status: :unprocessable_content
    end
  end

  # Disable 2FA
  def destroy
    current_user.disable_totp!
    redirect_to root_path, notice: "Two-factor authentication disabled."
  end

  # Show or generate backup codes for the logged-in user
  def backup_codes
    @user = current_user
    @plain_codes = session.delete(:last_generated_backup_codes)
    if @plain_codes.blank?
      # If no freshly generated codes in session and none exist, generate a new set now
      if @user.backup_codes_left == 0 || params[:force] == "1"
        @plain_codes = @user.generate_backup_codes!
        session[:last_generated_backup_codes] = @plain_codes # allow render after redirect in some flows
      end
    end
  end

  # Regenerate backup codes
  def regenerate_backup_codes
    @plain_codes = current_user.generate_backup_codes!
    session[:last_generated_backup_codes] = @plain_codes
    flash[:notice] = "Backup codes regenerated. Your previous codes are no longer valid."
    redirect_to two_factor_backup_codes_path
  end

  private

  def app_issuer
    Rails.application.class.module_parent_name || "RailsApp"
  end

  def qr_png_data_uri(url)
    return nil if url.blank?
    qr = RQRCode::QRCode.new(url)
    png = qr.as_png(
      bit_depth: 1,
      border_modules: 2,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      file: nil,
      fill: "white",
      module_px_size: 6,
      size: 240
    )
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end
end
