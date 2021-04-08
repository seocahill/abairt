# frozen_string_literal: true

Rails.application.routes.draw do
  resources :rangs do
    resources :dictionary_entries
  end
  resources :users
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resources :dictionary_entries do
    collection do
      patch :update_all
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "dictionary_entries#index"

  get "ceist", to: "ceist#new"
  post "ceist", to: "ceist#create"
  patch "ceist", to: "ceist#update"
  get "ceisteanna", to: "ceist#index"

  namespace :api do
    namespace :v1 do
      resources :dictionary_entries, only: :create
    end
  end
end
