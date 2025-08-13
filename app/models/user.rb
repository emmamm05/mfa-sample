class User < ApplicationRecord
  require 'securerandom'
  require 'openssl'

  attr_reader :password

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 8 }, allow_nil: true

  # Setter that hashes the password using PBKDF2-HMAC-SHA256 with per-user salt
  def password=(new_password)
    @password = new_password
    return if new_password.nil?

    self.password_salt = SecureRandom.hex(16)
    self.password_iterations ||= 120_000
    self.password_hash = pbkdf2_hex(new_password, password_salt, password_iterations)
  end

  # Authenticate with a candidate password
  def authenticate(candidate_password)
    return false if candidate_password.nil? || password_salt.blank? || password_hash.blank?

    candidate_hash = pbkdf2_hex(candidate_password, password_salt, password_iterations)
    ActiveSupport::SecurityUtils.secure_compare(candidate_hash, password_hash)
  end

  # BEGIN TOTP 2FA
  def totp_enabled?
    totp_enabled_at.present? && totp_secret.present?
  end

  def generate_totp_secret!
    self.totp_secret = ROTP::Base32.random_base32
  end

  def provisioning_uri(issuer: "MFA Sample")
    return nil if totp_secret.blank?
    label = email.presence || "user"
    ROTP::TOTP.new(totp_secret, issuer: issuer).provisioning_uri(label)
  end

  def verify_totp(code, drift: 1)
    return false if totp_secret.blank? || code.blank?
    totp = ROTP::TOTP.new(totp_secret)
    # Allow +/-1 time step (typically 30s) for clock skew
    totp.verify(code.to_s.gsub(/\s+/, ''), drift_behind: drift, drift_ahead: drift)
  end

  def enable_totp!
    self.totp_enabled_at = Time.current
    save!
  end

  def disable_totp!
    update!(totp_secret: nil, totp_enabled_at: nil)
  end
  # END TOTP 2FA

  private

  def pbkdf2_hex(password, salt_hex, iterations)
    salt = [salt_hex].pack('H*')
    # 32 bytes = 256-bit
    digest = OpenSSL::Digest::SHA256.new
    bytes = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations.to_i, 32, digest)
    bytes.unpack1('H*')
  end
end