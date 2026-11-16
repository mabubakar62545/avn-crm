Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resource  :registration, only: %i[new create]
  resources :email_verifications, only: %i[new create show update], param: :token

  # Account management
  namespace :account do
    resources :sessions, only: %i[index destroy] do
      delete :others, on: :collection
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "account/sessions#index"   # temporary until you build a dashboard
end