# frozen_string_literal: true

# Uses the full transcript stored on a VoiceRecording to correct the
# machine-generated word_or_phrase on each associated DictionaryEntry.
#
# The entries are ordered by region_start. Confirmed entries are skipped.
# Returns the number of entries corrected, or nil on failure.
class AutocorrectTranscriptionsService
  def initialize(voice_recording)
    @voice_recording = voice_recording
  end

  def process
    return unless @voice_recording.transcription.present?

    entries = @voice_recording.dictionary_entries.order(:region_start).to_a
    return 0 if entries.empty?

    corrected_texts = fetch_corrected_segments(entries)
    return unless corrected_texts.present?

    aligned = align_corrected_texts(entries, corrected_texts)
    aligned = snap_to_sentence_boundaries(aligned)

    updated_count = 0
    entries.zip(aligned).each do |entry, corrected_text|
      next if entry.confirmed?
      next if corrected_text.blank?
      next if corrected_text.strip == entry.word_or_phrase&.strip

      entry.update!(word_or_phrase: corrected_text.strip, translation: nil, status: :transcribed)
      updated_count += 1
    end

    updated_count
  rescue => e
    Rails.logger.error("AutocorrectTranscriptionsService failed: #{e.message}")
    nil
  end

  private

  def fetch_corrected_segments(entries)
    existing = entries.map.with_index(1) do |entry, i|
      "#{i}. #{entry.word_or_phrase.presence || "[blank]"} (#{entry.region_start} - #{entry.region_end})"
    end.join("\n")

    prompt = <<~PROMPT
      You are an Irish language expert correcting automatic speech recognition (ASR) output.

      Below is the full, accurate transcript of a recording:
      <transcript>
      #{@voice_recording.transcription}
      </transcript>

      The recording has been segmented into #{entries.size} sequential segments. Each segment's current (possibly inaccurate) ASR transcription is listed below in chronological order with the duration in brackets:
      #{existing}

      Using the full accurate transcript as the source of truth, provide the corrected Irish text for each segment in order. The segments together should cover the full transcript.

      Rules:
      - Return exactly #{entries.size} strings in the segments array, one per segment, in the same order.
      - Do not merge or split segments.
      - Each string should contain only the Irish text for that segment.
      - If a segment cannot be matched, return its original ASR text unchanged.
      - Prefer to start and end each segment at a sentence or clause boundary (full stop, question mark, exclamation mark, or a natural comma pause) where possible.
      - If a segment's assigned text would span two complete sentences, treat that as a signal the word boundary is slightly off — try to move words so the segment ends at the full stop.
    PROMPT

    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: "gpt-4.1",
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "corrected_segments",
          strict: true,
          schema: {
            type: "object",
            properties: {
              segments: {
                type: "array",
                items: { type: "string" }
              }
            },
            required: ["segments"],
            additionalProperties: false
          }
        }
      },
      messages: [
        { role: "system", content: "You are an Irish language expert." },
        { role: "user", content: prompt }
      ],
      temperature: 0.1
    })

    content = response.dig("choices", 0, "message", "content")
    return unless content.present?

    JSON.parse(content)["segments"]
  rescue JSON::ParserError => e
    Rails.logger.error("AutocorrectTranscriptionsService JSON parse error: #{e.message}")
    nil
  end

  def align_corrected_texts(entries, corrected_texts)
    return corrected_texts if corrected_texts.size == entries.size

    Rails.logger.warn(
      "AutocorrectTranscriptionsService: expected #{entries.size} segments, got #{corrected_texts.size} — aligning by timestamp"
    )
    align_by_word_rate(entries, corrected_texts)
  end

  # After text alignment, look at each consecutive pair of segments and snap
  # the boundary to a sentence-ending punctuation mark. If segment N ends
  # without terminal punctuation but contains a full-stop, question mark, or
  # exclamation mark in its latter half, move the words after that mark to the
  # front of segment N+1. This keeps each segment to at most one complete
  # sentence without touching the timestamp data.
  def snap_to_sentence_boundaries(texts)
    result = texts.map(&:dup)

    result.each_cons(2).with_index do |(current, _nxt), idx|
      words = current.split
      next if words.empty?
      next if words.last.match?(/[.?!]\z/)

      # Search backwards from the last word for a terminal-punctuation word
      # Only look in the latter 60% of the segment to avoid over-snapping
      search_from = (words.size * 0.4).floor
      pivot = nil
      words[search_from..].each_with_index do |word, i|
        pivot = search_from + i if word.match?(/[.?!]\z/)
      end

      next unless pivot

      # Move words after the pivot into the next segment
      tail = words[(pivot + 1)..] || []
      next if tail.empty?

      result[idx] = words[0..pivot].join(" ")
      result[idx + 1] = (tail + result[idx + 1].split).join(" ")
    end

    result
  end

  # When the API returns a different number of segments than entries, join all
  # corrected texts into a single word stream and redistribute words to each
  # entry proportionally by its speaking duration. This avoids repeating or
  # dropping corrected text that the timestamp-index approach would cause.
  def align_by_word_rate(entries, corrected_texts)
    words = corrected_texts.join(" ").split
    total_words = words.size
    total_duration = entries.sum { |e| e.region_end.to_f - e.region_start.to_f }

    result = []
    word_cursor = 0

    entries.each_with_index do |entry, idx|
      if idx == entries.size - 1
        result << words[word_cursor..].join(" ")
      else
        duration = entry.region_end.to_f - entry.region_start.to_f
        count = [(duration / total_duration * total_words).round, 1].max
        # Never consume so many words that remaining entries would get nothing
        remaining_entries = entries.size - idx - 1
        count = [count, total_words - word_cursor - remaining_entries].min
        result << words[word_cursor, count].join(" ")
        word_cursor += count
      end
    end

    result
  end
end
