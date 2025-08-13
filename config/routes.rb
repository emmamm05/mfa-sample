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

  # Root page
  root "home#index"
end
