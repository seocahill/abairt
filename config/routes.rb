# frozen_string_literal: true

Rails.application.routes.draw do
  resources :word_lists
  resources :voice_recordings do
    resources :dictionary_entries, only: :create, module: :voice_recordings
    member { get :preview }
  end

  scope controller: :pages do
    get :faq
  end

  resources :rangs do
    resources :dictionary_entries, only: :create, module: :rangs
  end

  resources :tags

  resources :users

  scope controller: :sessions do
    get "login" => :new
    post "login" => :create
    delete "logout" => :destroy
  end

  resources :dictionary_entries

  resources :word_list_dictionary_entries, only: [:create, :destroy, :update]

  get 'password_resets/new'
  post 'password_resets', to: 'password_resets#create'
  get 'password_resets/:token/edit', to: 'password_resets#edit', as: 'password_reset'
  patch 'password_resets/:token', to: 'password_resets#update', as: 'password_update'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "home#index"
end
