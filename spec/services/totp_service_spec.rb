# frozen_string_literal: true

require "rails_helper"
require "rotp"

RSpec.describe TotpService, type: :model do
  let(:user) { User.create!(email: "user@example.com", password: "Password!234") }
  subject(:service) { described_class.new(user) }

  describe "#enabled?" do
    it "is false when secret is missing" do
      user.update!(totp_secret: nil, totp_enabled_at: Time.current)
      expect(service.enabled?).to be(false)
    end

    it "is false when enabled_at is missing" do
      user.update!(totp_secret: "ABC", totp_enabled_at: nil)
      expect(service.enabled?).to be(false)
    end

    it "is true when both secret and enabled_at are present" do
      user.update!(totp_secret: "ABC", totp_enabled_at: Time.current)
      expect(service.enabled?).to be(true)
    end
  end

  describe "#generate_secret!" do
    it "assigns a new base32 secret without saving the user" do
      expect(user.totp_secret).to be_nil
      service.generate_secret!
      expect(user.totp_secret).to be_present
      # should not persist until saved explicitly
      reloaded = User.find(user.id)
      expect(reloaded.totp_secret).to be_nil
    end
  end

  describe "#provisioning_uri" do
    it "returns nil if there is no secret" do
      user.update!(totp_secret: nil)
      expect(service.provisioning_uri).to be_nil
    end

    it "returns a valid otpauth URI including issuer and email label" do
      service.generate_secret!
      secret = user.totp_secret
      uri = service.provisioning_uri(issuer: "MFA Sample")
      expect(uri).to start_with("otpauth://totp/")
      # issuer is URL-encoded; spaces may appear as %20
      expect(uri).to include("issuer=MFA%20Sample")
      # label uses email when present
      expect(uri).to include(URI.encode_www_form_component(user.email))
      # secret embedded
      expect(uri).to include(secret)
    end
  end

  describe "#verify" do
    before do
      service.generate_secret!
    end

    it "returns truthy for a valid current code" do
      code = ROTP::TOTP.new(user.totp_secret).now
      expect(service.verify(code)).to be_truthy
    end

    it "normalizes whitespace in submitted code" do
      code = ROTP::TOTP.new(user.totp_secret).now
      spaced = code.to_s.chars.each_slice(3).map(&:join).join(" ")
      expect(service.verify(spaced)).to be_truthy
    end

    it "returns false for blank code" do
      expect(service.verify(" ")).to be(false)
    end

    it "returns false for invalid code" do
      expect(service.verify("000000")).to be_falsey
    end

    it "passes drift options through to ROTP::TOTP#verify" do
      service.generate_secret!
      fake_totp = instance_double(ROTP::TOTP)
      expect(ROTP::TOTP).to receive(:new).with(user.totp_secret).and_return(fake_totp)
      expect(fake_totp).to receive(:verify).with("123456", drift_behind: 10, drift_ahead: 10).and_return(42)
      expect(service.verify("123456", drift: 10)).to eq(42)
    end
  end

  describe "#enable! and #disable!" do
    before do
      # seed some data to ensure disable! clears it
      user.update!(
        totp_secret: "SECRETTT",
        backup_codes_hashes: '["abc","def"]',
        backup_codes_salt: "1234",
        backup_codes_generated_at: Time.current
      )
    end

    it "persists totp_enabled_at timestamp on enable!" do
      expect(user.reload.totp_enabled_at).to be_nil
      service.enable!
      expect(user.reload.totp_enabled_at).to be_within(5.seconds).of(Time.current)
    end

    it "clears TOTP and backup codes data on disable!" do
      # first enable to set timestamp
      service.enable!
      service.disable!
      user.reload
      expect(user.totp_secret).to be_nil
      expect(user.totp_enabled_at).to be_nil
      expect(user.backup_codes_hashes).to be_nil
      expect(user.backup_codes_salt).to be_nil
      expect(user.backup_codes_generated_at).to be_nil
    end
  end
end
