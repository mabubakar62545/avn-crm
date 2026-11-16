Rails.application.routes.draw do
  # Authentication
  resource :session, only: %i[new create destroy]
  resource :two_factor_challenge, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]
  resource  :registration, only: %i[new create]
  resources :email_verifications, only: %i[new create show update], param: :token

  # Account management
  namespace :account do
    resource :two_factor, only: %i[new create destroy]

    resources :sessions, only: %i[index destroy] do
      delete :others, on: :collection
    end
  end

  namespace :admin do
    resources :audit_events, only: :index
    resources :users, only: %i[index show update] do
      member do
        patch  :unlock
        delete :revoke_sessions
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboards#show"
end
