Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "daily(/:date)", to: "daily_logs#show", as: :daily_log
  get "reflection", to: "daily_reflections#show", as: :reflection
  get "reflection/evening", to: "daily_reflections#evening", as: :evening_reflection
  post "reflection/entries/:id/priority", to: "daily_reflections#mark_priority",
    as: :mark_priority_reflection
  post "reflection/entries/:id/priority/clear", to: "daily_reflections#clear_priority",
    as: :clear_priority_reflection
  get "month(/:month)", to: "monthly_logs#show", as: :monthly_log
  get "month/:month/migration", to: "monthly_migrations#show", as: :monthly_migration
  post "month/:month/migration/inventory", to: "monthly_migrations#inventory", as: :monthly_migration_inventory
  get "month/:month/migration/outgoing", to: "monthly_migrations#outgoing", as: :monthly_migration_outgoing
  post "month/:month/migration/outgoing/:id/strike", to: "monthly_migrations#outgoing_strike",
    as: :strike_monthly_migration_outgoing
  post "month/:month/migration/outgoing/:id/tasks", to: "monthly_migrations#outgoing_tasks",
    as: :tasks_monthly_migration_outgoing
  post "month/:month/migration/outgoing/:id/collection", to: "monthly_migrations#outgoing_collection",
    as: :collection_monthly_migration_outgoing
  post "month/:month/migration/outgoing/:id/future", to: "monthly_migrations#outgoing_future",
    as: :future_monthly_migration_outgoing
  get "month/:month/migration/future", to: "monthly_migrations#future", as: :monthly_migration_future
  post "month/:month/migration/future/:id/strike", to: "monthly_migrations#future_strike",
    as: :strike_monthly_migration_future
  post "month/:month/migration/future/:id/tasks", to: "monthly_migrations#future_tasks",
    as: :tasks_monthly_migration_future
  post "month/:month/migration/future/:id/calendar", to: "monthly_migrations#future_calendar",
    as: :calendar_monthly_migration_future
  post "month/:month/migration/undo", to: "monthly_migrations#undo", as: :undo_monthly_migration
  get "month/:month/migration/complete", to: "monthly_migrations#complete", as: :monthly_migration_complete
  get "future", to: "future_logs#show", as: :future_log
  get "index", to: "collections#index", as: :journal_index
  resources :collections, only: %i[create show update destroy]
  resources :entries, only: %i[create update] do
    member do
      post :complete
      post :reopen
      post :strike
      post :migrate
      post :schedule
      post :move_to_collection
      post :children
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
