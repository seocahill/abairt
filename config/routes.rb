# frozen_string_literal: true

class AdminConstraint
  def matches?(request)
    return false unless request.session[:user_id]
    user = User.find_by(id: request.session[:user_id], confirmed: true)
    user&.admin?
  end
end

Rails.application.routes.draw do
  draw :madmin

  # Mission Control for job monitoring - admin only
  constraints(AdminConstraint.new) do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  namespace :api do
    resources :voice_recordings, only: [] do
      post 'diarization_webhook', to: 'voice_recordings/diarization_webhooks#create'
    end

    # Speech to Text API endpoint
    post 'speech_to_text', to: 'speech_to_text#create'

    # Text to Speech API endpoint
    resources :text_to_speech, only: [:create]
  end

  resources :word_lists
  resources :registrations, only: [:new, :create]
  resources :voice_recordings do
    resources :dictionary_entries, module: :voice_recordings, only: [:index, :create, :update]
    resources :speakers, module: :voice_recordings, only: [:index, :update]
    member do
      get :preview
      get :add_region
      get :regions
      get :import_status
      get 'subtitles(/:lang)', to: 'voice_recordings#subtitles', defaults: { format: 'vtt' }, as: :subtitles
    end
    resource :diarization, only: [:create]
  end

  resource :import, only: [:new, :create], module: :voice_recordings

  resources :tags

  resources :users
  
  resources :admin_emails do
    member do
      post :send_email
      post :send_to_self
    end
  end

  scope controller: :sessions do
    get "login" => :new
    get 'login_with_token/:token' => :login_with_token, as: :login_with_token
    post "login" => :create
    delete "logout" => :destroy
  end

  resource :reify, only: :create

  resources :dictionary_entries do
    post :update_region, on: :member
    post :generate_audio, on: :member
  end

  resources :word_list_dictionary_entries, only: [:create, :destroy, :update]

  get 'password_resets/new'
  post 'password_resets', to: 'password_resets#create'

  get 'home', to: 'home#index'
  
  get 'translator_leaderboard', to: 'translator_leaderboard#index'

  resources :practice_recordings, only: [:create]

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  # health
  get "up" => "health#show"
  
  # Service status
  get "status" => "status#index"

  root to: 'application#root_redirect'
end
