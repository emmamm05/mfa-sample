# frozen_string_literal: true

require "securerandom"
require "openssl"
require "json"
require "active_support/security_utils"

# Service class to manage backup codes for a user
class BackupCodesService
  DEFAULT_COUNT = 10
  DEFAULT_LENGTH = 10

  def initialize(user)
    @user = user
  end

  # Generate a set of backup codes, persist only their hashes on the user, and return
  # the plain codes for one-time display.
  def generate!(count: DEFAULT_COUNT, length: DEFAULT_LENGTH)
    @user.backup_codes_salt = SecureRandom.hex(16)
    plain_codes = Array.new(count) { readable_code(length) }
    hashes = plain_codes.map { |code| backup_code_hash(code) }
    @user.backup_codes_hashes = JSON.generate(hashes)
    @user.backup_codes_generated_at = Time.current
    @user.save!
    plain_codes
  end

  # Number of remaining backup codes
  def remaining_codes_count
    parse_backup_hashes.size
  end

  # Attempts to consume a backup code; returns true if a code matched and was removed
  def consume!(code)
    return false if code.to_s.strip.empty?

    normalized = normalize_code(code)
    hashes = parse_backup_hashes
    return false if hashes.empty? || @user.backup_codes_salt.to_s.empty?

    candidate = backup_code_hash(normalized)

    match_index = hashes.find_index do |h|
      begin
        ActiveSupport::SecurityUtils.secure_compare(h, candidate)
      rescue StandardError
        false
      end
    end

    return false if match_index.nil?

    hashes.delete_at(match_index)
    @user.backup_codes_hashes = JSON.generate(hashes)
    @user.save!
    true
  end

  private

  def readable_code(length)
    alphabet = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9]
    Array.new(length) { alphabet.sample }.join
  end

  def normalize_code(code)
    code.to_s.strip.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def backup_code_hash(code)
    CryptoUtils::PBKDF2.hex(code, @user.backup_codes_salt)
  end

  def parse_backup_hashes
    raw = @user.backup_codes_hashes
    return [] if raw.nil? || raw == ""
    JSON.parse(raw)
  rescue StandardError
    []
  end
end
