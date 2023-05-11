# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :voice_recordings do
    resources :dictionary_entries, only: :create
  end
  resources :voice_recordings do
    member do
      get :preview
    end
  end

  scope controller: :pages do
    get :faq
  end

  resources :rangs do
    resources :dictionary_entries
  end

  resources :tags

  resources :users

  scope controller: :sessions do
    get "login" => :new
    post "login" => :create
    delete "logout" => :destroy
  end

  resources :dictionary_entries do
    collection do
      patch :update_all
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "home#index"
end
