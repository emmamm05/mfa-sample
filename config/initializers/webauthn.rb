# frozen_string_literal: true

WebAuthn.configure do |config|
  # Relying Party name for display
  config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "MFA Sample")

  # Origin(s) allowed. For development, default to localhost:3000.
  origin = ENV["WEBAUTHN_ORIGIN"] || "http://localhost:3000"
  config.origin = origin

  # rp_id can be set explicitly; default is derived from origin's host
  # config.rp_id = URI.parse(origin).host

  # Timeouts (optional defaults)
  config.credential_options_timeout = 120000 # 120s

  config.algorithms = %w[ES256 RS256]
end
