Rails.application.routes.draw do
  # Health check route - used by Render to verify the app is running
  get "up" => "rails/health#show", as: :rails_health_check

  # Root route - when someone visits your site, show the subscribe form
  root "subscribers#new"
  get "/admin/trigger-poll", to: "admin#trigger_poll"

  post "/twilio/inbound", to: "twilio#inbound"

  # Subscribers routes
  # GET  /subscribers/new - show the subscribe form
  # POST /subscribers     - handle form submission and save to database
  resources :subscribers, only: [ :new, :create ]
end
