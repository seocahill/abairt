# frozen_string_literal: true

require 'csv'
class DictionaryEntry < ApplicationRecord
  has_one_attached :media

  after_create_commit { broadcast_prepend_to 'dictionary_entries' }
  after_destroy_commit { broadcast_remove_to 'dictionary_entries' }

  include PgSearch::Model
  pg_search_scope :search_translation, against: :translation, using: { tsearch: { dictionary: 'english' } }

  class << self
    def to_csv
      attributes = %w[word_or_phrase translation media_url]

      CSV.generate(headers: true) do |csv|
        csv << attributes

        all.find_each do |user|
          csv << attributes.map { |attr| user.send(attr) }
        end
      end
    end
  end

  def media_url
    Rails.application.routes.url_helpers.rails_blob_path(media, only_path: true)
    end
end
