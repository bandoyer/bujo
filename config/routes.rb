Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "daily(/:date)", to: "daily_logs#show", as: :daily_log
  get "month(/:month)", to: "monthly_logs#show", as: :monthly_log
  get "future", to: "future_logs#show", as: :future_log
  resources :entries, only: :create do
    member do
      post :complete
      post :reopen
      post :strike
      post :migrate
      post :schedule
    end
  end
  resource :theme, only: :update
  resource :lettering, only: :update

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "daily_logs#show"
end
