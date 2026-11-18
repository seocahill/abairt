# frozen_string_literal: true

require "csv"

class DictionaryEntry < ApplicationRecord
  include CsvExportable

  # Every change is kept, with who made it, and none is ever pruned: the first
  # edit's version holds the original (machine) text, which is training data.
  has_paper_trail only: [:word_or_phrase, :translation, :accuracy_status], on: %i[create update destroy]

  has_one_attached :media

  belongs_to :speaker, class_name: "User", foreign_key: "speaker_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  belongs_to :translator, class_name: "User", foreign_key: "translator_id", optional: true
  belongs_to :voice_recording, optional: true, counter_cache: true

  has_many :fts_dictionary_entries, class_name: "FtsDictionaryEntry", foreign_key: "rowid"
  has_many :segment_prompts, dependent: :destroy
  has_many :asr_hypotheses, dependent: :destroy
  has_many :asr_eval_set_entries, dependent: :restrict_with_error

  acts_as_taggable_on :tags

  MAYO_DIALECTS = %w[tuaisceart_mhaigh_eo connacht_ó_thuaidh acaill lár_chonnachta].freeze

  # Versions that hold earlier text. The creation version only records who
  # made the entry and when, so it has nothing to show or restore.
  def edits
    versions.reject { |version| version.event == "create" }
  end

  scope :has_recording, -> { joins(:media_attachment) }
  scope :mayo_dialect, -> { joins(:speaker).where(users: { dialect: MAYO_DIALECTS }) }
  scope :has_translation, -> { where.not(translation: [nil, ""]) }

  # Scopes are for filtering visability and training data
  # Note: 'pending' conflicts with status enum, so using 'unconfirmed_accuracy' and 'confirmed_accuracy'
  scope :unconfirmed_accuracy, -> { where(accuracy_status: 0) }
  scope :confirmed_accuracy, -> { where(accuracy_status: 1) }
  
  # Legacy aliases - these may conflict with status enum, use unconfirmed_accuracy/confirmed_accuracy instead
  def self.pending
    unconfirmed_accuracy
  end
  
  def self.validated
    confirmed_accuracy
  end
  
  def self.confirmed
    confirmed_accuracy
  end
  # Ground truth for ASR evaluation: checked by a human, has audio and text.
  # The criteria live here only, so they can change without touching the rest.
  scope :asr_eval_candidates, -> { confirmed_accuracy.has_recording.where.not(word_or_phrase: [nil, ""]).joins(:speaker).where.not(users: {role: :temporary}) }
  scope :updated_since, ->(timestamp) { where("updated_at > ?", timestamp) }

  # Entries whose Irish contains the given words, best match first. Searched as
  # a phrase in the full-text index, so accents and case don't matter.
  scope :matching_irish, ->(text) {
    search = DictionarySearch.new(text)
    next none if search.blank?

    joins(:fts_dictionary_entries)
      .where("fts_dictionary_entries MATCH ?", search.phrase_expression(column: :word_or_phrase))
      .reorder("rank")
  }

  # Full-text search of Irish and English, best match first. Safe for any typed text.
  scope :search, ->(text) {
    search = DictionarySearch.new(text)
    next none if search.blank?

    joins(:fts_dictionary_entries)
      .where("fts_dictionary_entries MATCH ?", search.expression)
      .distinct
      .order("rank")
  }

  validates :word_or_phrase, uniqueness: { case_sensitive: false }, allow_blank: true, unless: -> { voice_recording_id || speaker&.ai? || speaker&.student? }

  validate :dictionary_entries_cannot_exceed_segments_count, on: :create
  validate :cannot_edit_when_confirmed, on: :update

  def cannot_edit_when_confirmed
    return unless confirmed?
    return if accuracy_status_changed? # Allow deconfirmation
    return if translation_was.blank? && !word_or_phrase_changed? # Allow if there was no translation before and no word or phrase change

    if word_or_phrase_changed? || translation_changed?
      errors.add(:base, "Cannot edit confirmed entries. Please deconfirm first.")
    end
  end

  # Based on CEFR scale i.e. low: < B2, fair: B2, good: C, excellent: native
  enum :quality, %i[
    low
    fair
    good
    excellent
  ]

  enum :accuracy_status, {
    unconfirmed: 0,
    confirmed: 1
  }

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

  def create_embedding
    EmbedDictionaryEntryJob.perform_later(self.id)
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
