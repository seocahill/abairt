# frozen_string_literal: true

# Extracts metadata from a voice recording using AI analysis
# Analyzes all transcribed segments to identify:
# - Themes (farming, fishing, folklore, etc.)
# - Locations mentioned
# - Speakers identified
# - Time periods or historical references
# - Keywords for searchability
class VoiceRecordingMetadataService
  THEMES = %w[
    farming fishing folklore music religion politics weather
    family death birth marriage emigration famine war
    education work crafts food drink animals nature
    supernatural storytelling proverbs customs festivals
    placenames genealogy language health poverty wealth
    community childhood old_age travel trade
  ].freeze

  def initialize(voice_recording)
    @voice_recording = voice_recording
  end

  def process
    return unless @voice_recording.dictionary_entries.any?

    combined_text = build_combined_text
    return if combined_text.blank?

    metadata = extract_metadata(combined_text)
    return unless metadata

    @voice_recording.update!(
      metadata: metadata,
      metadata_extracted_at: Time.current
    )

    apply_tags(metadata["themes"]) if metadata["themes"].present?

    metadata
  end

  private

  def build_combined_text
    entries = @voice_recording.dictionary_entries
      .where.not(translation: [nil, ""])
      .pluck(:word_or_phrase, :translation)

    entries.map { |irish, english| "#{irish} (#{english})" }.join("\n")
  end

  def extract_metadata(text)
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: "gpt-4.1",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt(text) }
      ],
      response_format: { type: "json_object" },
      temperature: 0.3
    })

    JSON.parse(response.dig("choices", 0, "message", "content"))
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("Metadata extraction failed: #{e.message}")
    nil
  end

  def system_prompt
    <<~PROMPT
      You are an expert in Irish language and culture, specializing in analyzing oral history recordings.
      Your task is to extract structured metadata from transcribed audio segments.

      You understand Irish placenames, historical context, and cultural references.
      You can identify themes, locations, people mentioned, and time periods from context.
    PROMPT
  end

  def user_prompt(text)
    <<~PROMPT
      Analyze the following transcribed segments from an Irish language recording.
      Extract metadata in JSON format with these fields:

      {
        "themes": ["array of relevant themes from: #{THEMES.join(", ")}"],
        "locations": ["array of place names mentioned (townlands, counties, countries)"],
        "speakers_mentioned": ["names of people mentioned in the recording"],
        "time_period": "estimated era or time period discussed (e.g., '1940s', 'pre-famine', 'childhood memories')",
        "keywords": ["5-10 searchable keywords in English"],
        "summary": "2-3 sentence English summary of the recording content",
        "dialect_indicators": "any dialect features noticed (Ulster, Connacht, Munster)"
      }

      Only include fields where you have reasonable confidence. Use empty arrays [] for fields with no data.

      Transcribed segments:
      #{text}
    PROMPT
  end

  def apply_tags(themes)
    valid_themes = themes.select { |t| THEMES.include?(t.downcase.gsub(" ", "_")) }
    @voice_recording.tag_list.add(valid_themes)
    @voice_recording.save!
  end
end
