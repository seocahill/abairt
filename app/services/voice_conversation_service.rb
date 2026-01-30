# frozen_string_literal: true

# AI-driven voice conversation service for transcription correction
# Processes user voice input and generates appropriate responses and actions
class VoiceConversationService
  Response = Data.define(:text, :audio_url, :action, :data)

  ACTIONS = %w[
    speak search play_segment update_transcription update_translation
    next_segment complete none
  ].freeze

  def initialize(session)
    @session = session
    @abair = AbairAdapter.new(dialect: :ulster, gender: :female)
  end

  # Process user voice input and return response
  # user_audio can be a file path or transcribed text
  def process(user_input)
    # Transcribe if audio file provided
    user_text = transcribe_if_audio(user_input)
    return error_response("I couldn't understand that. Could you repeat?") if user_text.blank?

    # Log user message
    @session.add_message(role: "user", content: user_text)

    # Get AI response based on current state and input
    ai_response = generate_response(user_text)

    # Log assistant message
    @session.add_message(role: "assistant", content: ai_response[:text])

    # Execute any actions
    execute_action(ai_response[:action], ai_response[:data])

    # Generate audio response
    audio_url = synthesize_response(ai_response[:text])

    Response.new(
      text: ai_response[:text],
      audio_url: audio_url,
      action: ai_response[:action],
      data: ai_response[:data]
    )
  end

  private

  def transcribe_if_audio(input)
    return input if input.is_a?(String) && !File.exist?(input)

    # Use OpenAI Whisper for English voice commands
    transcribe_english(input)
  end

  def transcribe_english(audio_path)
    client = openai_client
    response = client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: File.open(audio_path, "rb"),
        language: "en"
      }
    )
    response["text"]
  rescue StandardError => e
    Rails.logger.error("Whisper transcription failed: #{e.message}")
    nil
  end

  def generate_response(user_text)
    client = openai_client
    messages = build_messages(user_text)

    response = client.chat(parameters: {
      model: "gpt-4.1",
      messages: messages,
      response_format: { type: "json_object" },
      temperature: 0.7
    })

    parse_ai_response(response.dig("choices", 0, "message", "content"))
  rescue StandardError => e
    Rails.logger.error("AI response generation failed: #{e.message}")
    { text: "I'm having trouble processing that. Could you try again?", action: "none", data: {} }
  end

  def build_messages(user_text)
    [
      { role: "system", content: system_prompt },
      *format_history,
      { role: "user", content: user_text }
    ]
  end

  def system_prompt
    <<~PROMPT
      You are a helpful voice assistant for Abairt, an Irish language transcription platform.
      You help native Irish speakers review and correct transcriptions using voice commands.

      Current session state: #{@session.state}
      #{current_context}

      Your role:
      1. Help users find recordings to work on (by topic, location, or random)
      2. Play audio segments and read transcriptions aloud
      3. Ask for confirmation or corrections
      4. Handle spelling clarifications conversationally
      5. Move through segments efficiently

      Respond in JSON format:
      {
        "text": "Your spoken response in English",
        "action": "one of: #{ACTIONS.join(", ")}",
        "data": { action-specific data }
      }

      Action data formats:
      - search: { "query": "search terms" }
      - play_segment: { "entry_id": 123 }
      - update_transcription: { "entry_id": 123, "text": "corrected Irish text" }
      - update_translation: { "entry_id": 123, "text": "corrected English text" }
      - next_segment: {}
      - complete: {}
      - speak: { "irish_text": "text to speak in Irish" }
      - none: {}

      Keep responses concise and conversational. Users may have difficulty seeing screens.
      When confirming corrections, repeat them back clearly.
      If a spelling is unclear, ask them to spell it out letter by letter.
    PROMPT
  end

  def current_context
    context_parts = []

    if @session.voice_recording
      vr = @session.voice_recording
      context_parts << "Working on: #{vr.title}"
      context_parts << "Recording summary: #{vr.summary}" if vr.summary.present?
      context_parts << "Total segments: #{vr.dictionary_entries.count}"
    end

    if @session.current_entry
      entry = @session.current_entry
      context_parts << "Current segment ##{entry_position}"
      context_parts << "Irish transcription: #{entry.word_or_phrase}"
      context_parts << "English translation: #{entry.translation}"
      context_parts << "Status: #{entry.accuracy_status}"
    end

    if @session.context["pending_correction"]
      context_parts << "Pending correction: #{@session.context["pending_correction"]}"
    end

    context_parts.join("\n")
  end

  def entry_position
    return 0 unless @session.current_entry && @session.voice_recording

    @session.voice_recording.dictionary_entries
      .where("region_start <= ?", @session.current_entry.region_start)
      .count
  end

  def format_history
    @session.recent_history(limit: 6).map do |msg|
      { role: msg["role"], content: msg["content"] }
    end
  end

  def parse_ai_response(content)
    parsed = JSON.parse(content)
    {
      text: parsed["text"] || "I didn't understand that.",
      action: parsed["action"] || "none",
      data: parsed["data"] || {}
    }
  rescue JSON::ParserError
    { text: content, action: "none", data: {} }
  end

  def execute_action(action, data)
    case action
    when "search"
      perform_search(data["query"])
    when "update_transcription"
      update_transcription(data["entry_id"], data["text"])
    when "update_translation"
      update_translation(data["entry_id"], data["text"])
    when "next_segment"
      @session.advance_to_next_entry!
    when "complete"
      @session.transition_to!("complete")
    end
  end

  def perform_search(query)
    results = VoiceRecording.search_by_metadata(query).limit(5)
    @session.store_context("search_results", results.pluck(:id, :title))
    @session.transition_to!("selecting_recording")
  end

  def update_transcription(entry_id, text)
    entry = DictionaryEntry.find(entry_id)
    entry.update!(word_or_phrase: text, accuracy_status: :confirmed)
    @session.clear_context("pending_correction")
    @session.transition_to!("confirming_translation")
  end

  def update_translation(entry_id, text)
    entry = DictionaryEntry.find(entry_id)
    entry.update!(translation: text)
    @session.transition_to!("playing_segment")
  end

  def synthesize_response(text)
    # For English responses, we'll use the browser's speech synthesis
    # Only use Abair for Irish text
    nil
  end

  def error_response(text)
    Response.new(text: text, audio_url: nil, action: "none", data: {})
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )
  end
end
