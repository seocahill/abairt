# frozen_string_literal: true

class AdminConstraint
  def matches?(request)
    return false unless request.session[:user_id]
    user = User.find_by(id: request.session[:user_id], confirmed: true)
    user&.admin?
  end
end

Rails.application.routes.draw do
  # Mission Control for job monitoring - admin only
  constraints(AdminConstraint.new) do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # OAuth 2 provider (Doorkeeper) + Model Context Protocol server for Claude web.
  #
  # Discovery/authorization flow used by Claude web:
  #   1. POST /mcp -> 401 with WWW-Authenticate pointing at the resource metadata
  #   2. GET  /.well-known/oauth-protected-resource   (RFC 9728)
  #   3. GET  /.well-known/oauth-authorization-server  (RFC 8414)
  #   4. POST /oauth/register  (RFC 7591 Dynamic Client Registration)
  #   5. GET  /oauth/authorize + POST /oauth/token  (PKCE authorization code grant)
  #   6. POST /mcp with a bearer token
  use_doorkeeper

  # Dynamic Client Registration (RFC 7591) - Doorkeeper does not ship this endpoint.
  post "/oauth/register", to: "oauth/registrations#create"

  # OAuth discovery metadata. The path-suffixed variants support clients that append the
  # protected resource path (e.g. `/.well-known/oauth-protected-resource/mcp`).
  get "/.well-known/oauth-protected-resource", to: "well_known#oauth_protected_resource"
  get "/.well-known/oauth-protected-resource/*resource", to: "well_known#oauth_protected_resource"
  get "/.well-known/oauth-authorization-server", to: "well_known#oauth_authorization_server"
  get "/.well-known/oauth-authorization-server/*resource", to: "well_known#oauth_authorization_server"

  # MCP Streamable HTTP transport endpoint.
  match "/mcp", to: "mcp#handle", via: %i[get post delete]

  namespace :api do
    resources :voice_recordings, only: [] do
      post 'diarization_webhook', to: 'voice_recordings/diarization_webhooks#create'
    end

    # Telegram Bot API webhook. No handshake to answer: setWebhook is a one-off
    # call at setup, and the secret comes back in a header on every delivery.
    post "telegram/webhook", to: "telegram/webhooks#create"

    # Speech to Text API endpoint
    post 'speech_to_text', to: 'speech_to_text#create'

    # Text to Speech API endpoint
    resources :text_to_speech, only: [:create]

    # Public API for confirmed transcriptions
    resources :transcriptions, only: [:index, :show]

    # Island context: find Mayo dialect entries relevant to a Caotharnach island description
    resources :island_context, only: [:create]
    
    # OpenAPI schema
    get 'openapi', to: 'openapi#show', defaults: { format: 'json' }
  end

  resources :word_lists
  resources :registrations, only: [:new, :create]
  resources :voice_recordings do
    collection do
      get :tags
    end
    resources :dictionary_entries, module: :voice_recordings, only: [:index, :create, :update] do
      member do
        post :confirm
        post :deconfirm
      end
    end
    resource :claim, module: :voice_recordings, only: [:create, :destroy]
    resources :speakers, module: :voice_recordings, only: [:index, :update] do
      collection do
        get :search
      end
    end
    member do
      get :preview
      get :add_region
      get :regions
      get :import_status
      get 'subtitles(/:lang)', to: 'voice_recordings#subtitles', defaults: { format: 'vtt' }, as: :subtitles
      post :retranscribe
      post :autocorrect
    end
    resource :diarization, only: [:create]
  end

  resource :import, only: [:new, :create], module: :voice_recordings

  resources :tags

  resources :users do
    member do
      post :generate_api_token
      post :regenerate_api_token
      delete :revoke_api_token
    end
  end

  namespace :admin do
    get "data_dashboard", to: "data_dashboard#index", as: :data_dashboard

    get "island_context_playground", to: "island_context_playground#index", as: :island_context_playground

    resources :api, only: [:index] do
      collection do
        post :generate
        post :regenerate
        delete :revoke
      end
    end

    resources :media_imports do
      member do
        post :process_now
        post :retry
      end
      collection do
        post :process_all_pending
      end
    end

    resources :questions, only: [:index] do
      member do
        post :deliver
      end
    end

    resources :locations, only: [:index, :edit, :update] do
      member do
        post :geocode
      end
    end

    resources :users, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
      member do
        post :telegram_invite
        post :approve
        post :reject
        post :generate_api_token
        post :regenerate_api_token
        post :revoke_api_token
      end
      collection do
        post :bulk_approve
        post :bulk_reject
      end
    end
  end
  
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

  resources :login_requests, only: [:new, :create]

  resource :password, only: [:edit, :update]

  # Progressive web app: the learner installs this to the home screen so asking
  # a question is tap, hold, release.
  # Formats are pinned rather than negotiated: Rails' stock version of these
  # routes resolves the template off the Accept header, which 500s for a client
  # that asks for text/html.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: {format: :json}
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: {format: :js}

  get 'home', to: 'home#index'

  # API Documentation
  get 'api/docs', to: 'api_docs#show', as: :api_docs
  
  resources :translator_leaderboard, only: [:index, :show], controller: 'translator_leaderboard'

  resources :practice_recordings, only: [:create]

  resources :questions, only: [:index, :new, :create, :show, :destroy] do
    # A draft is sent by creating its delivery.
    resource :delivery, only: [:create], module: :questions
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  # health
  get "up" => "health#show"
  
  # Service status
  get "status" => "status#index"

  root to: 'application#root_redirect'
end
