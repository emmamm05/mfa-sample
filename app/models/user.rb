class User < ApplicationRecord
  require 'securerandom'
  require 'openssl'
  require 'json'

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
  # Delegate TOTP logic to service class
  def totp_enabled?
    TotpService.new(self).enabled?
  end

  def generate_totp_secret!
    TotpService.new(self).generate_secret!
  end

  def provisioning_uri(issuer: "MFA Sample")
    TotpService.new(self).provisioning_uri(issuer: issuer)
  end

  def verify_totp(code, drift: 1)
    TotpService.new(self).verify(code, drift: drift)
  end

  def enable_totp!
    TotpService.new(self).enable!
  end

  def disable_totp!
    TotpService.new(self).disable!
  end
  # END TOTP 2FA

  # BEGIN Backup codes
  # Delegate backup codes logic to service class
  def generate_backup_codes!(count: 10, length: 10)
    BackupCodesService.new(self).generate!(count: count, length: length)
  end

  def backup_codes_left
    BackupCodesService.new(self).remaining_codes_count
  end

  # Attempts to consume a backup code; returns true if a code matched and was removed
  def consume_backup_code!(code)
    BackupCodesService.new(self).consume!(code)
  end
  # END Backup codes

  private

  def pbkdf2_hex(password, salt_hex, iterations)
    salt = [salt_hex].pack('H*')
    # 32 bytes = 256-bit
    digest = OpenSSL::Digest::SHA256.new
    bytes = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations.to_i, 32, digest)
    bytes.unpack1('H*')
  end

  def readable_code(length)
    # Generate a base32-like uppercase code without confusing chars
    alphabet = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9]
    Array.new(length) { alphabet.sample }.join
  end

  def normalize_code(code)
    code.to_s.strip.upcase.gsub(/[^A-Z0-9]/, '')
  end

  def backup_code_hash(code)
    # Hash the normalized code with salt via PBKDF2 for consistency
    pbkdf2_hex(code, backup_codes_salt, 100_000)
  end

  def parse_backup_hashes
    return [] if backup_codes_hashes.blank?
    JSON.parse(backup_codes_hashes) rescue []
  end
end