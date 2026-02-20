# frozen_string_literal: true

# Analyzes voice recording transcripts to extract:
# - Location names (townlands, parishes, regions)
# - Speaker names and metadata
# - Dialect indicators
#
# Uses GPT-4o to parse transcripts and infer metadata from context.
#
class TranscriptAnalysisService
  MAYO_DIALECT_REGIONS = %w[erris achill tourmakeady east_mayo other].freeze

  def initialize(voice_recording)
    @voice_recording = voice_recording
    @client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )
  end

  def analyze
    return { skipped: true, reason: "no_transcript" } unless transcript_text.present?

    analysis = extract_metadata_from_transcript
    return { skipped: true, reason: "analysis_failed" } unless analysis

    result = {
      locations: [],
      speakers: [],
      dialect_region: nil,
      raw_analysis: analysis
    }

    # Process locations
    if analysis["locations"].present?
      result[:locations] = process_locations(analysis["locations"])
    end

    # Process speakers
    if analysis["speakers"].present?
      result[:speakers] = process_speakers(analysis["speakers"])
    end

    # Set primary dialect region
    result[:dialect_region] = analysis["dialect_region"]

    # Store analysis on voice recording
    update_voice_recording_metadata(result)

    result
  end

  private

  def transcript_text
    @transcript_text ||= begin
      # Combine all dictionary entries for this recording, ordered by timestamp
      entries = @voice_recording.dictionary_entries
        .order(:region_start)
        .pluck(:word_or_phrase, :translation)
      entries.map { |irish, english| "#{irish} (#{english})" }.join("\n")
    end
  end

  def extract_metadata_from_transcript
    prompt = build_analysis_prompt

    response = @client.chat(parameters: {
      model: "gpt-4o",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: prompt }
      ],
      temperature: 0.2,
      response_format: { type: "json_object" }
    })

    content = response.dig("choices", 0, "message", "content")
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error("TranscriptAnalysis JSON parse failed: #{e.message}")
    nil
  rescue => e
    Rails.logger.error("TranscriptAnalysis failed: #{e.message}")
    nil
  end

  def system_prompt
    <<~PROMPT
      You are an expert in Irish language dialects, particularly Mayo Irish (Gaeilge Mhaigh Eo).
      You analyze transcripts of native Irish speakers to extract metadata.

      Mayo Irish dialect regions:
      - erris (Iorras): Northwest Mayo - Belmullet, Glenamoy, Carrowteige, Barnatra, Geesala
      - achill (Acaill): Achill Island and surroundings - Dooagh, Dooniver, Corrán, Kildavnet
      - tourmakeady (Tuar Mhic Éadaigh): South Mayo near Lough Mask - Finny, Partry, Glencastle
      - east_mayo: Eastern Mayo towards Sligo/Roscommon border - Castlebar, Ballyhaunis, Ballinrobe
      - other: Areas outside traditional Gaeltacht or mixed dialects

      Dialect markers to look for:
      - Erris: tends to use "tigeann" (comes), "tig leat" (you can), certain vowel shifts
      - Achill: distinctive pronunciation patterns, some unique vocabulary
      - Tourmakeady: influenced by south Connacht, some unique local terms

      When analyzing, pay attention to:
      - Place names mentioned in the text
      - Personal names (especially older Irish names)
      - References to local geography (mountains, lakes, townlands)
      - Dialect-specific vocabulary or constructions
      - Context clues about the speaker's background
    PROMPT
  end

  def build_analysis_prompt
    title_context = @voice_recording.title.present? ? "Recording title: #{@voice_recording.title}\n" : ""
    description_context = @voice_recording.description.present? ? "Description: #{@voice_recording.description}\n" : ""

    <<~PROMPT
      Analyze this transcript from a Mayo Irish speaker and extract metadata.

      IMPORTANT: The recording title and description often contain the speaker's name and location.
      Parse these carefully - they are typically the most reliable source of this information.

      #{title_context}#{description_context}
      Transcript (Irish with English translations):
      #{transcript_text.truncate(8000)}

      Return a JSON object with:
      {
        "locations": [
          {
            "name": "location name",
            "irish_name": "ainm Gaeilge (if different)",
            "type": "townland|parish|barony|county|region",
            "dialect_region": "erris|achill|tourmakeady|east_mayo|other",
            "confidence": "high|medium|low",
            "source": "title|description|transcript",
            "context": "why you identified this location"
          }
        ],
        "speakers": [
          {
            "name": "speaker name if mentioned",
            "gender": "male|female|unknown",
            "estimated_age_group": "elderly|middle_aged|young|unknown",
            "native_speaker": true|false,
            "dialect_region": "erris|achill|tourmakeady|east_mayo|other",
            "confidence": "high|medium|low",
            "source": "title|description|transcript",
            "context": "evidence for these assessments"
          }
        ],
        "dialect_region": "most likely dialect region based on linguistic features",
        "dialect_evidence": ["list of dialect markers found in the text"],
        "topics": ["main topics discussed in the recording"]
      }

      If you cannot determine something with confidence, use "unknown" or omit the field.
      Only include locations and speakers you have actual evidence for.
      Info from title/description should have "high" confidence if clearly stated.
    PROMPT
  end

  def process_locations(location_data)
    location_data.filter_map do |loc|
      next if loc["confidence"] == "low"

      location = Location.find_or_create_from_analysis(
        name: loc["irish_name"] || loc["name"],
        dialect_region: loc["dialect_region"] || "other"
      )

      # Update with Irish name if we have both
      if loc["irish_name"].present? && loc["name"] != loc["irish_name"]
        location.update(irish_name: loc["irish_name"]) if location.irish_name.blank?
      end

      {
        location: location,
        confidence: loc["confidence"],
        context: loc["context"]
      }
    end
  end

  def process_speakers(speaker_data)
    speaker_data.filter_map do |spk|
      next if spk["name"].blank? && spk["confidence"] == "low"

      {
        name: spk["name"],
        gender: spk["gender"],
        dialect_region: spk["dialect_region"],
        native_speaker: spk["native_speaker"],
        estimated_age_group: spk["estimated_age_group"],
        confidence: spk["confidence"],
        context: spk["context"]
      }
    end
  end

  def update_voice_recording_metadata(result)
    metadata = {
      analyzed_at: Time.current,
      locations: result[:locations].map { |l| { id: l[:location].id, name: l[:location].name, confidence: l[:confidence] } },
      speakers: result[:speakers],
      dialect_region: result[:dialect_region],
      dialect_evidence: result.dig(:raw_analysis, "dialect_evidence"),
      topics: result.dig(:raw_analysis, "topics")
    }

    @voice_recording.update(metadata_analysis: metadata)

    # Set primary location if we found one with high confidence
    primary_location = result[:locations].find { |l| l[:confidence] == "high" }
    if primary_location && @voice_recording.location_id.nil?
      @voice_recording.update(location_id: primary_location[:location].id)
    end
  end
end
