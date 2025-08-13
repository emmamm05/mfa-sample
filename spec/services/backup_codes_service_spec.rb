# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackupCodesService, type: :model do
  let(:user) { User.create!(email: "user2@example.com", password: "Password!234") }
  subject(:service) { described_class.new(user) }

  describe "#generate!" do
    it "returns plain codes and persists only hashes, salt, and timestamp" do
      codes = service.generate!
      expect(codes).to be_an(Array)
      expect(codes.length).to eq(BackupCodesService::DEFAULT_COUNT)
      expect(codes.uniq.length).to eq(codes.length)

      user.reload
      expect(user.backup_codes_salt).to be_present
      expect(user.backup_codes_generated_at).to be_within(5.seconds).of(Time.current)

      # hashes are stored as JSON array; should not contain plaintext codes
      hashes = JSON.parse(user.backup_codes_hashes)
      expect(hashes).to be_a(Array)
      expect(hashes.length).to eq(codes.length)
      codes.each do |code|
        expect(hashes).not_to include(code)
      end
    end

    it "honors custom count and length" do
      codes = service.generate!(count: 5, length: 12)
      expect(codes.length).to eq(5)
      expect(codes.first.length).to eq(12)
    end
  end

  describe "#remaining_codes_count" do
    it "reflects number of stored hashes" do
      expect(service.remaining_codes_count).to eq(0)
      service.generate!(count: 3)
      expect(service.remaining_codes_count).to eq(3)
    end
  end

  describe "#consume!" do
    it "returns false for blank input" do
      expect(service.consume!(" ")).to be(false)
    end

    it "returns false when no codes are generated" do
      expect(service.consume!("ANYCODE")).to be(false)
    end

    it "consumes a valid code and cannot consume it twice" do
      codes = service.generate!(count: 2)
      code = codes.first

      # normalization: allow lowercase and spaces/dashes
      normalized_variant = code.downcase.chars.each_slice(2).map(&:join).join("-")

      expect(service.consume!(normalized_variant)).to be(true)
      expect(service.remaining_codes_count).to eq(1)

      # second attempt should fail
      expect(service.consume!(code)).to be(false)
      expect(service.remaining_codes_count).to eq(1)
    end

    it "does not match when salt or hashes are missing" do
      # Manually clear state to simulate corrupted user
      user.update!(backup_codes_hashes: nil, backup_codes_salt: nil)
      expect(service.consume!("SOMECODE")).to be(false)
    end
  end
end
