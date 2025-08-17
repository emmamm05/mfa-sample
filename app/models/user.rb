class User < ApplicationRecord
  require "securerandom"
  require "openssl"
  require "json"

  PASSWORD_SALT_BYTES = 16

  attr_reader :password

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 8 }, allow_nil: true

  # Setter that hashes the password using PBKDF2-HMAC-SHA256 with per-user salt
  def password=(new_password)
    @password = new_password
    return if new_password.nil?

    self.password_salt = SecureRandom.hex(PASSWORD_SALT_BYTES)
    self.password_hash = CryptoUtils::PBKDF2.hex(new_password, password_salt)
  end

  # Authenticate with a candidate password
  def authenticate(candidate_password)
    return false if candidate_password.nil? || password_salt.blank? || password_hash.blank?

    candidate_hash = CryptoUtils::PBKDF2.hex(candidate_password, password_salt)
    ActiveSupport::SecurityUtils.secure_compare(candidate_hash, password_hash)
  end

  # BEGIN TOTP 2FA
  # Delegate TOTP logic to service class
  def totp_enabled?
    totp_service.enabled?
  end

  def generate_totp_secret!
    totp_service.generate_secret!
  end

  def provisioning_uri(issuer: "MFA Sample")
    totp_service.provisioning_uri(issuer: issuer)
  end

  def verify_totp(code, drift: 1)
    totp_service.verify(code, drift: drift)
  end

  def enable_totp!
    totp_service.enable!
  end

  def disable_totp!
    totp_service.disable!
  end

  # END TOTP 2FA

  # BEGIN Backup codes
  # Delegate backup codes logic to service class
  def generate_backup_codes!(count: 10, length: 10)
    backup_codes_service.generate!(count: count, length: length)
  end

  def backup_codes_left
    backup_codes_service.remaining_codes_count
  end

  # Attempts to consume a backup code; returns true if a code matched and was removed
  def consume_backup_code!(code)
    backup_codes_service.consume!(code)
  end

  # END Backup codes

  has_many :webauthn_credentials, dependent: :destroy

  private

  def totp_service
    @totp_service ||= TotpService.new(self)
  end

  def backup_codes_service
    @backup_codes_service ||= BackupCodesService.new(self)
  end
end
