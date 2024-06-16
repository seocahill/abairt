# frozen_string_literal: true

Rails.application.routes.draw do
  draw :madmin
  resources :word_lists
  resources :seomras, only: :destroy
  resources :registrations, only: [:new, :create]
  resources :voice_recordings do
    resources :dictionary_entries, only: :create, module: :voice_recordings
    member { get :preview }
    member { post :add_region }
    collection { get :map }
  end

  resources :rangs do
    resources :dictionary_entries, only: :create, module: :rangs
  end

  resources :tags

  resources :users

  scope controller: :sessions do
    get "login" => :new
    get 'login_with_token/:token' => :login_with_token, as: :login_with_token
    post "login" => :create
    delete "logout" => :destroy
  end

  resource :reify, only: :create

  resources :dictionary_entries do
    post :update_region, on: :member
  end

  resources :word_list_dictionary_entries, only: [:create, :destroy, :update]

  # learning
  resources :learning_sessions, only: [:create, :show, :index]
  resources :learning_progresses, only: [:show, :update]
  resources :courses
  resources :items
  resources :articles

  get 'password_resets/new'
  post 'password_resets', to: 'password_resets#create'

  get 'home', to: 'home#index'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  # health
  get "up" => "health#show"

  root to: 'application#root_redirect'
end
