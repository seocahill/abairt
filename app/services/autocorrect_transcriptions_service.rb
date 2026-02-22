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
    align_by_timestamp(entries, corrected_texts)
  end

  # When the API returns a different number of segments than entries, distribute
  # corrected texts proportionally using each entry's midpoint timestamp.
  def align_by_timestamp(entries, corrected_texts)
    total_start = entries.first.region_start.to_f
    total_end = entries.last.region_end.to_f
    total_duration = total_end - total_start
    n = corrected_texts.size

    entries.map do |entry|
      midpoint = ((entry.region_start.to_f + entry.region_end.to_f) / 2.0 - total_start) / total_duration
      idx = (midpoint * n).floor.clamp(0, n - 1)
      corrected_texts[idx]
    end
  end
end
