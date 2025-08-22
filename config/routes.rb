Rails.application.routes.draw do
  # Stripe webhooks
  post "webhooks/stripe", to: "webhooks#stripe"
  
  # Checkout routes
  post "checkout/create", to: "checkout#create"
  get "checkout/success", to: "checkout#success"
  get "checkout/cancel", to: "checkout#cancel"
  get "profile", to: "profile#show"
  get "profile/edit", to: "profile#edit"
  patch "profile", to: "profile#update"
  get "onboarding", to: "onboarding#index"
  get "onboarding/welcome"
  get "onboarding/profile"
  patch "onboarding/profile", to: "onboarding#update_profile"
  get "onboarding/advanced"
  patch "onboarding/advanced", to: "onboarding#update_advanced"
  get "onboarding/complete"
  resources :photos, only: [:index, :show, :new, :create] do
    member do
      get :display_heic
    end
  end
  get "dashboard/index"
  resource :session
  resources :passwords, param: :token
  get "early-access", to: "early_access#index", as: :early_access
  post "early-access", to: "early_access#create"
  get "dashboard", to: "dashboard#index"
  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
