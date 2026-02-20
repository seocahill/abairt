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

    unless corrected_texts.size == entries.size
      Rails.logger.error(
        "AutocorrectTranscriptionsService: expected #{entries.size} segments, got #{corrected_texts.size}"
      )
      return
    end

    updated_count = 0
    entries.zip(corrected_texts).each do |entry, corrected_text|
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
      "#{i}. #{entry.word_or_phrase.presence || "[blank]"}"
    end.join("\n")

    prompt = <<~PROMPT
      You are an Irish language expert correcting automatic speech recognition (ASR) output.

      Below is the full, accurate transcript of a recording:
      <transcript>
      #{@voice_recording.transcription}
      </transcript>

      The recording has been segmented into #{entries.size} sequential segments. Each segment's current (possibly inaccurate) ASR transcription is listed below in chronological order:
      #{existing}

      Using the full accurate transcript as the source of truth, provide the corrected Irish text for each segment in order. The segments together should cover the full transcript.

      Rules:
      - Return ONLY a valid JSON array of strings, one element per segment, in the same order.
      - Do not merge or split segments - there must be exactly #{entries.size} elements.
      - Each element should contain only the Irish text for that segment.
      - If a segment cannot be matched, return its original ASR text unchanged.
      - No explanations, no markdown, just the raw JSON array.
    PROMPT

    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: "gpt-4.1",
      messages: [
        { role: "system", content: "You are an Irish language expert. Return only valid JSON arrays." },
        { role: "user", content: prompt }
      ],
      temperature: 0.1
    })

    content = response.dig("choices", 0, "message", "content")
    return unless content.present?

    # Strip any accidental markdown fences
    content = content.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error("AutocorrectTranscriptionsService JSON parse error: #{e.message}")
    nil
  end
end
