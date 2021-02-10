json.extract! dictionary_entry, :id, :word_or_phrase, :translation, :created_at, :updated_at
json.url dictionary_entry_url(dictionary_entry, format: :json)
