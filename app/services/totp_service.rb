# frozen_string_literal: true

require 'rotp'

# Service class to manage TOTP for a user
class TotpService
  DEFAULT_DRIFT = 1

  def initialize(user)
    @user = user
  end

  # Whether TOTP is enabled for the user
  def enabled?
    @user.totp_enabled_at.present? && @user.totp_secret.present?
  end

  # Generate and assign a new TOTP secret (does not save the user)
  def generate_secret!
    @user.totp_secret = ROTP::Base32.random_base32
  end

  # Build provisioning URI for authenticator apps
  def provisioning_uri(issuer: "MFA Sample")
    return nil if @user.totp_secret.to_s.empty?

    label = @user.email.presence || "user"
    ROTP::TOTP.new(@user.totp_secret, issuer: issuer).provisioning_uri(label)
  end

  # Verify a user-provided code against the stored secret
  # Returns truthy time-step index on success or false/nil on failure (same as rotp)
  def verify(code, drift: DEFAULT_DRIFT)
    return false if @user.totp_secret.to_s.empty? || code.to_s.strip.empty?

    totp = ROTP::TOTP.new(@user.totp_secret)
    normalized = code.to_s.gsub(/\s+/, '')
    totp.verify(normalized, drift_behind: drift, drift_ahead: drift)
  end

  # Mark TOTP as enabled (persists timestamp)
  def enable!
    @user.totp_enabled_at = Time.current
    @user.save!
  end

  # Disable TOTP and clear related data (also disables backup codes as per current behavior)
  def disable!
    @user.update!(
      totp_secret: nil,
      totp_enabled_at: nil,
      backup_codes_hashes: nil,
      backup_codes_salt: nil,
      backup_codes_generated_at: nil
    )
  end
end
