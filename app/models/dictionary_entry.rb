# frozen_string_literal: true

require "csv"

class DictionaryEntry < ApplicationRecord
  has_one_attached :media

  has_many :rang_entries, dependent: :destroy
  has_many :rangs, through: :rang_entries

  belongs_to :speaker, class_name: "User", foreign_key: "speaker_id", optional: true

  has_many :fts_dictionary_entries, class_name: "FtsDictionaryEntry", foreign_key: "rowid"
  belongs_to :voice_recording, optional: true

  has_many :word_list_dictionary_entries, dependent: :destroy
  has_many :word_lists, through: :word_list_dictionary_entries

  enum status: [:normal, :ceist, :foghraíocht]

  before_create :create_audio_snippet, unless: -> { voice_recording_id.nil? }

  acts_as_taggable_on :tags

  accepts_nested_attributes_for :rang_entries

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
    false
  end

  def create_audio_snippet
    require 'open3'

    return unless voice_recording_id

    # Select the region you want to extract
    duration = region_end - region_start

    # Set the output file path and delete cache
    output_path = "/tmp/#{region_id}.mp3"
    File.delete output_path rescue nil
    voice_recording.media.open do |file|
      if voice_recording.media.audio?
        # Extract the selected region and save it as a new MP3 file using ffmpeg
        stdout, stderr, status = Open3.capture3("ffmpeg -ss #{region_start} -i #{file.path} -t #{duration} -c:a copy #{output_path}")
      else
        stdout, stderr, status = Open3.capture3("ffmpeg -ss #{region_start} -i #{file.path} -t #{duration} -vn #{output_path}")
      end
      # Attach the new file to a Recording model using Active Storage
      self.media.attach(io: File.open(output_path), filename: "#{region_id}.mp3")
    end
  end
end
