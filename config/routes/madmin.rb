# Below are the routes for madmin
namespace :madmin do
  resources :grupas
  resources :word_lists
  resources :voice_recordings
  resources :users
  resources :tags
  resources :rangs
  resources :dictionary_entries
  namespace :active_storage do
    resources :variant_records
  end
  namespace :paper_trail do
    resources :versions
  end
  namespace :active_storage do
    resources :attachments
  end
  resources :word_list_dictionary_entries
  resources :rang_entries
  namespace :active_storage do
    resources :blobs
  end
  root to: "dashboard#show"
end
