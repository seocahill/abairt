# frozen_string_literal: true

Rails.application.routes.draw do
  draw :madmin
  resources :word_lists
  resources :seomras, only: :destroy
  resources :registrations, only: [:new, :create]
  resources :voice_recordings do
    resources :dictionary_entries, only: :create, module: :voice_recordings
    member { get :preview }
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

  resource :reify, only: :create

  resources :dictionary_entries

  resources :word_list_dictionary_entries, only: [:create, :destroy, :update]

  get 'password_resets/new'
  post 'password_resets', to: 'password_resets#create'

  get 'home', to: 'home#index'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: 'application#root_redirect'
end
