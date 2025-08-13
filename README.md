# MFA Sample (Rails 8)

A minimal Rails 8 sample app that demonstrates adding multi-factor authentication (MFA) to a traditional email/password login using:

- TOTP (Time-based One-Time Password) codes compatible with authenticator apps like Google Authenticator, 1Password, and Authy.
- Backup recovery codes that users can generate, view once, and use if they lose access to their authenticator app.

## Features

- Sign up and log in with email + password.
- Enable 2FA (TOTP) by scanning a QR code and confirming a code.
- Enforced second step during sign-in when 2FA is enabled (code from app or a backup code).
- View/regenerate backup codes. Codes are hashed at rest and consumed on use.
- Disable 2FA.

## How it works (high‑level)

- Passwords are hashed with PBKDF2-HMAC-SHA256 per-user salt (see `app/lib/crypto_utils.rb` and `User` model).
- TOTP secrets and verification are handled by `TotpService` (`app/services/totp_service.rb`) using the `rotp` gem.
- Backup codes are generated and stored as PBKDF2 hashes via `BackupCodesService` (`app/services/backup_codes_service.rb`). Only the plain codes are shown once to the user.
- The login flow (`SessionsController`) sends users with 2FA enabled to a second step (`TwoFactorAuthsController`) where codes are verified.
- A simple home page shows 2FA status and links to enable/disable and manage backup codes.

## Tech stack

- Rails 8, Turbo/Stimulus, sqlite3
- rotp (TOTP), rqrcode + chunky_png (QR code PNG)
- RSpec, Capybara, Cuprite for tests

## Quick start

1. Setup
   - Ensure you have a recent Ruby (see `Gemfile`) and bundler installed.
   - Install dependencies:

     ```bash
     bundle install
     ```

   - Setup the database:

     ```bash
     bin/rails db:setup
     ```

2. Run the app
   - Start the server:

     ```bash
     bin/rails server
     ```

   - Visit: http://localhost:3000

3. Try it out
   - Sign up with an email and password.
   - From the home page, click "Enable 2FA".
   - Scan the QR code with an authenticator app, enter the shown code to confirm.
   - Save the backup codes that appear (you will only see them once).
   - Log out and log back in: you will be prompted for your 2FA code. A valid backup code works as a fallback and will be consumed.

## Running tests

```bash
bundle exec rspec
```

## Key files

- `app/models/user.rb` — password hashing, 2FA delegations
- `app/services/totp_service.rb` — TOTP secrets, provisioning URI, verification, enable/disable
- `app/services/backup_codes_service.rb` — generate, store (hashed), and consume backup codes
- `app/controllers/sessions_controller.rb` — login, 2FA gate
- `app/controllers/two_factor_auths_controller.rb` — setup, activate, verify, backup codes, disable
- `app/views/home/index.html.erb` — entry point with 2FA status/actions

## Security notes

- TOTP secrets are stored on the User record (for demo purposes). In production, consider encryption-at-rest for secrets.
- Backup codes are hashed using PBKDF2 and compared using constant-time comparison.
- Be mindful of brute-force protections, rate limiting, and alerting in a real application.

## LLM Usage

- This example app was developed with JetBrains RubyMine + Junie (ChatGPT 5.0)