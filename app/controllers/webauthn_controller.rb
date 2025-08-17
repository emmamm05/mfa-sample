require "base64"

class WebauthnController < ApplicationController
  before_action :require_login, only: [:options_creation, :create]

  # Generate options for creating a credential (attestation)
  def options_creation
    user = current_user
    existing_ids = user.webauthn_credentials.pluck(:external_id).map { |id| Base64.urlsafe_decode64(id) }

    options = WebAuthn::Credential.options_for_create(
      user: { id: user_handle(user), name: user.email, display_name: user.name.presence || user.email },
      exclude: existing_ids
    )

    store_challenge!(options.challenge, :webauthn_creation_challenge)

    render json: options
  end

  # Verify and persist newly created credential
  def create
    user = current_user
    begin
      webauthn_credential = WebAuthn::Credential.from_create(params.require(:credential))
      webauthn_credential.verify(retrieve_challenge!(:webauthn_creation_challenge))

      record = user.webauthn_credentials.build(
        external_id: Base64.urlsafe_encode64(webauthn_credential.id, padding: false),
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        transports: Array(webauthn_credential.transports).join(","),
        nickname: params[:nickname].presence
      )
      record.save!
      render json: { ok: true }
    rescue => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end
  end

  # Generate options for assertion (request) during 2FA verify step
  def options_request
    user = User.find_by(id: session[:pre_2fa_user_id])
    return render json: { error: "Not in 2FA flow" }, status: :unauthorized unless user

    credentials = user.webauthn_credentials
    allow = credentials.map do |cred|
      { id: Base64.urlsafe_decode64(cred.external_id), transports: cred.transports_array }
    end

    options = WebAuthn::Credential.options_for_get(allow: allow.presence)
    store_challenge!(options.challenge, :webauthn_request_challenge)

    render json: options
  end

  # Verify assertion and complete sign-in
  def verify
    user = User.find_by(id: session[:pre_2fa_user_id])
    return render json: { error: "Not in 2FA flow" }, status: :unauthorized unless user

    begin
      assertion = WebAuthn::Credential.from_get(params.require(:credential))

      cred = user.webauthn_credentials.find_by!(external_id: Base64.urlsafe_encode64(assertion.id, padding: false))

      assertion.verify(
        retrieve_challenge!(:webauthn_request_challenge),
        public_key: cred.public_key,
        sign_count: cred.sign_count
      )

      # Update sign count to prevent cloned authenticator reuse
      cred.update!(sign_count: assertion.sign_count)

      # Complete login
      session.delete(:pre_2fa_user_id)
      session[:user_id] = user.id

      render json: { ok: true }
    rescue => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def user_handle(user)
    # The user handle must be bytes; encode stable unique string
    user.id.to_s
  end

  def store_challenge!(challenge, key)
    session[key] = challenge
  end

  def retrieve_challenge!(key)
    c = session.delete(key)
    raise "challenge missing" if c.blank?
    c
  end
end
