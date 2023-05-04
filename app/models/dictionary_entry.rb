# frozen_string_literal: true

require "csv"

class DictionaryEntry < ApplicationRecord
  has_one_attached :media

  has_many :rang_entries, dependent: :destroy
  has_many :rangs, through: :rang_entries

  has_many :fts_dictionary_entries, class_name: "FtsDictionaryEntry", foreign_key: "rowid"
  belongs_to :voice_recording, optional: true

  enum status: [:normal, :ceist, :foghraíocht]

  after_create_commit { broadcast_prepend_to "dictionary_entries" }
  after_update_commit { broadcast_replace_later_to "dictionary_entries" }
  after_destroy_commit { broadcast_remove_to "dictionary_entries" }

  acts_as_taggable_on :tags

  scope :has_recording, -> { joins(:media_attachment) }

  validates :word_or_phrase, uniqueness: { case_sensitive: false }, allow_blank: true

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
    return "" unless media.attached?

    Rails.application.routes.url_helpers.url_for(media)
  end

  def transcription?
    rangs.first&.media&.audio?
  end
end
