# frozen_string_literal: true

class DictionaryEntry < ApplicationRecord
  has_one_attached :media

  include PgSearch::Model
  pg_search_scope :search_translation, against: :translation, using: { tsearch: { dictionary: 'english' } }
end
