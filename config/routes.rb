# frozen_string_literal: true

Rails.application.routes.draw do
  resources :dictionary_entries
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: 'dictionary_entries#index'
end
