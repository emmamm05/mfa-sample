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
    update!(totp_secret: nil, totp_enabled_at: nil, backup_codes_hashes: nil, backup_codes_salt: nil, backup_codes_generated_at: nil)
  end
  # END TOTP 2FA

  # BEGIN Backup codes
  # Generate a set of backup codes, store only hashed codes and return the plain codes for display once
  def generate_backup_codes!(count: 10, length: 10)
    self.backup_codes_salt = SecureRandom.hex(16)
    plain_codes = Array.new(count) { readable_code(length) }
    hashes = plain_codes.map { |c| backup_code_hash(c) }
    self.backup_codes_hashes = JSON.generate(hashes)
    self.backup_codes_generated_at = Time.current
    save!
    plain_codes
  end

  def backup_codes_left
    parsed = parse_backup_hashes
    parsed.size
  end

  # Attempts to consume a backup code; returns true if a code matched and was removed
  def consume_backup_code!(code)
    return false if code.blank?
    normalized = normalize_code(code)
    hashes = parse_backup_hashes
    return false if hashes.empty? || backup_codes_salt.blank?

    candidate = backup_code_hash(normalized)
    # constant-time compare over list
    match_index = hashes.find_index { |h| ActiveSupport::SecurityUtils.secure_compare(h, candidate) rescue false }
    return false if match_index.nil?

    hashes.delete_at(match_index)
    self.backup_codes_hashes = JSON.generate(hashes)
    save!
    true
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