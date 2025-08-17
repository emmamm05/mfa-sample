Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication routes
  get  "/signup", to: "registrations#new",  as: :signup
  post "/signup", to: "registrations#create"

  get  "/login",  to: "sessions#new",       as: :login
  post "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy",  as: :logout

  # Two-factor authentication routes
  get  "/2fa/verify", to: "two_factor_auths#new",    as: :two_factor_verify
  post "/2fa/verify", to: "two_factor_auths#create"
  get  "/2fa/setup",  to: "two_factor_auths#setup",  as: :two_factor_setup
  post "/2fa/setup",  to: "two_factor_auths#activate"
  delete "/2fa",       to: "two_factor_auths#destroy", as: :two_factor_disable
  get  "/2fa/backup_codes", to: "two_factor_auths#backup_codes", as: :two_factor_backup_codes
  post "/2fa/backup_codes", to: "two_factor_auths#regenerate_backup_codes"

  # WebAuthn endpoints (JSON)
  scope "/webauthn" do
    post "/options/creation", to: "webauthn#options_creation"
    post "/create",           to: "webauthn#create"
    post "/options/request",  to: "webauthn#options_request"
    post "/verify",           to: "webauthn#verify"
  end

  # Root page
  root "home#index"
end
