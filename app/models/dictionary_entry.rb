# frozen_string_literal: true

require "csv"

class DictionaryEntry < ApplicationRecord
  include CsvExportable

  # only save new version if different user
  has_paper_trail only: [:word_or_phrase, :translation], limit: 10, on: %i[update destroy]

  has_one_attached :media

  belongs_to :speaker, class_name: "User", foreign_key: "speaker_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  belongs_to :translator, class_name: "User", foreign_key: "translator_id", optional: true
  belongs_to :voice_recording, optional: true, counter_cache: true

  has_many :fts_dictionary_entries, class_name: "FtsDictionaryEntry", foreign_key: "rowid"
  has_many :word_list_dictionary_entries, dependent: :destroy

  acts_as_taggable_on :tags

  scope :has_recording, -> { joins(:media_attachment) }

  # Scopes are for filtering visability and training data
  scope :pending, -> { where(quality: %i[low fair]) }
  scope :validated, -> { where(quality: %i[good excellent]) }

  validates :word_or_phrase, uniqueness: { case_sensitive: false }, allow_blank: true, unless: -> { voice_recording_id || speaker&.ai? || speaker&.student? }

  # validates :quality, inclusion: { in: %w[low fair], message: "can only be set to low or fair unless speaker is B2 level or higher" }, unless: -> { Current.user&.ability&.in?(%w[B2 C1 C2 native]) }

  validate :dictionary_entries_cannot_exceed_segments_count

  # Based on CEFR scale i.e. low: < B2, fair: B2, good: C, excellent: native
  enum :quality, %i[
    low
    fair
    good
    excellent
  ]

  enum :status, {
    pending: 0,
    transcribed: 10,
    translated: 20,
    processed: 30
  }

  def media_url
    return "" unless media.attached?

    Rails.application.routes.url_helpers.url_for(media)
  end

  def transcription?
    false
  end

  def create_audio_snippet(source_file_path = nil)
    # Create audio snippet of entry range from voice recording
    output_path = AudioSnippetService.new(self, source_file_path).process

    # Return if no snippet created
    return unless output_path.present?
    # Auto transcribe if no values present
    return if word_or_phrase.present?

    AudioTranscriptionService.new(self, output_path).process
  ensure
    File.delete output_path rescue nil
  end

  def create_ai_response(rang)
    ChatBotJob.perform_later(self, rang)
  end

  def auto_tag
    AutoTagService.new(self).process
  end

  def synthesize_text_to_speech_and_store
    SynthesizeTextToSpeechService.new(self).process
  end

  def translate
    translation_text = TranslationService.new(self).translate
    if translation_text.present?
      update!(translation: translation_text)
    end
  end

  def post_process
    PostProcessEntryJob.perform_later(self)
  end

  private

  def dictionary_entries_cannot_exceed_segments_count
    return unless voice_recording_id && voice_recording

    segments_count = voice_recording.segments_count
    return if segments_count == 0 # Skip validation if no segments data available

    current_entries_count = voice_recording.dictionary_entries.size
    # If this is a new record, increment the count
    current_entries_count += 1 if new_record?

    if current_entries_count > segments_count
      errors.add(:base, "Cannot create more dictionary entries (#{current_entries_count}) than available segments (#{segments_count}) for this voice recording")
    end
  end

end
