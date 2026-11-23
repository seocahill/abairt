# frozen_string_literal: true

module Transcription
  # Accepts one candidate from a transcription run (#133), on a person's say-so.
  #
  # - A `differs` candidate puts its new Irish on the entry through the entry's
  #   own update, so paper_trail keeps the old text and every validation applies.
  #   The translation is kept as it was, and remembered on the candidate so the
  #   entry can say it may now be out of date. A confirmed entry is never
  #   changed: it has to be deconfirmed first.
  # - A `new_segment` candidate becomes a new unconfirmed entry, set up the way
  #   the import pipeline sets one up: its audio clip, translation and tags
  #   follow in PostProcessEntryJob. Its speaker is left for a person to choose,
  #   because a new Fotheidil job numbers its speakers afresh.
  #
  # `current_text` is the entry's text as the person saw it. If the entry has
  # changed since, nothing is changed, so a correction made meanwhile is never
  # overwritten unseen.
  #
  #   service = Transcription::AcceptCandidate.new(candidate, by: user)
  #   service.call  # => true, or false with service.error
  class AcceptCandidate
    attr_reader :error

    def self.call(...)
      new(...).call
    end

    def initialize(candidate, by:, current_text: nil)
      @candidate = candidate
      @user = by
      @current_text = current_text
    end

    def call
      @candidate.with_lock do
        next fail_with("This line has already been #{@candidate.status}.") unless @candidate.pending?

        @candidate.new_segment? ? add_entry : replace_text
      end
      @added_entry&.post_process
      @error.nil?
    rescue ActiveRecord::RecordInvalid => e
      fail_with(e.record.errors.full_messages.to_sentence)
    end

    private

    def replace_text
      entry = @candidate.dictionary_entry
      entry.lock!
      return fail_with("This line is confirmed. Deconfirm it first to use the new text.") if entry.confirmed?
      return fail_with("This line has changed since the page was loaded. Look at it again before choosing.") if changed_since_seen?(entry)

      entry.update!(word_or_phrase: @candidate.word_or_phrase)
      resolve!(translation_at_acceptance: entry.translation)
    end

    # The segment id is left off: the new job numbers its segments afresh, so
    # it could match an imported entry's id (the pipeline's idempotency key).
    def add_entry
      recording = @candidate.transcription_run.voice_recording
      entry = DictionaryEntry.new(
        voice_recording: recording,
        owner: recording.owner,
        region_start: @candidate.region_start,
        region_end: @candidate.region_end,
        word_or_phrase: @candidate.word_or_phrase,
        added_in_review: true
      )
      entry.save!
      AsrHypothesis.record(entry, provider: "fotheidil", text: @candidate.word_or_phrase)
      resolve!(dictionary_entry: entry)
      @added_entry = entry
    end

    def resolve!(**attrs)
      @candidate.update!(status: :accepted, resolved_by: @user, resolved_at: Time.current, **attrs)
    end

    def changed_since_seen?(entry)
      !@current_text.nil? && entry.word_or_phrase.to_s != @current_text.to_s
    end

    def fail_with(message)
      @error = message
      false
    end
  end
end
