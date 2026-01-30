# frozen_string_literal: true

# AI-driven voice conversation service for transcription correction
# Uses OpenAI function calling to handle navigation, playback, and corrections
class VoiceConversationService
  Response = Data.define(:text, :action, :data, :speak_english)

  def initialize(session)
    @session = session
    @abair = AbairAdapter.new(dialect: :ulster, gender: :female)
  end

  # Process user voice input and return response
  def process(user_input)
    user_text = transcribe_if_audio(user_input)
    return error_response("I couldn't understand that. Could you repeat?") if user_text.blank?

    @session.add_message(role: "user", content: user_text)

    result = call_with_tools(user_text)

    @session.add_message(role: "assistant", content: result[:text])

    Response.new(
      text: result[:text],
      action: result[:action],
      data: result[:data],
      speak_english: result[:text] # AI response is always spoken in English
    )
  end

  private

  def transcribe_if_audio(input)
    return input if input.is_a?(String) && !File.exist?(input)

    transcribe_english(input)
  end

  def transcribe_english(audio_path)
    response = openai_client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: File.open(audio_path, "rb"),
        language: "en"
      }
    )
    response["text"]
  rescue => e
    Rails.logger.error("Whisper transcription failed: #{e.message}")
    nil
  end

  def call_with_tools(user_text)
    messages = [
      { role: "system", content: system_prompt },
      *format_history,
      { role: "user", content: user_text }
    ]

    response = openai_client.chat(parameters: {
      model: "gpt-4.1",
      messages: messages,
      tools: tool_definitions,
      tool_choice: "auto",
      temperature: 0.7
    })

    message = response.dig("choices", 0, "message")
    process_tool_response(message)
  rescue => e
    Rails.logger.error("AI response failed: #{e.message}")
    { text: "I'm having trouble. Could you try again?", action: "none", data: {} }
  end

  def process_tool_response(message)
    tool_calls = message["tool_calls"]

    if tool_calls.present?
      tool_call = tool_calls.first
      function_name = tool_call.dig("function", "name")
      arguments = JSON.parse(tool_call.dig("function", "arguments") || "{}")

      execute_tool(function_name, arguments)
    else
      { text: message["content"], action: "none", data: {} }
    end
  end

  def execute_tool(name, args)
    case name
    when "confirm_entry"
      confirm_current_entry
    when "next_entry"
      advance_to_next
    when "skip_entry"
      skip_current_entry
    when "play_original"
      play_original_audio
    when "play_transcription"
      play_irish_transcription
    when "play_translation"
      play_english_translation
    when "play_context"
      play_surrounding_context(args["entries_before"] || 1, args["entries_after"] || 1)
    when "search_recordings"
      search_recordings(args["query"])
    when "select_recording"
      select_recording(args["recording_id"])
    when "update_transcription"
      update_transcription(args["corrected_text"])
    when "update_translation"
      update_translation(args["corrected_text"])
    else
      { text: "I didn't understand that command.", action: "none", data: {} }
    end
  end

  # Navigation tools

  def confirm_current_entry
    entry = @session.current_entry
    return { text: "No segment is currently selected.", action: "none", data: {} } unless entry

    entry.update!(accuracy_status: :confirmed)
    next_entry = @session.advance_to_next_entry!

    if next_entry
      {
        text: "Confirmed. Moving to the next segment.",
        action: "play_transcription",
        data: { entry_id: next_entry.id, irish_text: next_entry.word_or_phrase }
      }
    else
      {
        text: "Confirmed. That was the last segment. Well done!",
        action: "complete",
        data: {}
      }
    end
  end

  def advance_to_next
    next_entry = @session.advance_to_next_entry!

    if next_entry
      {
        text: "Next segment.",
        action: "play_transcription",
        data: { entry_id: next_entry.id, irish_text: next_entry.word_or_phrase }
      }
    else
      {
        text: "That was the last segment.",
        action: "complete",
        data: {}
      }
    end
  end

  def skip_current_entry
    next_entry = @session.advance_to_next_entry!

    if next_entry
      {
        text: "Skipped. Here's the next one.",
        action: "play_transcription",
        data: { entry_id: next_entry.id, irish_text: next_entry.word_or_phrase }
      }
    else
      {
        text: "Skipped. That was the last segment.",
        action: "complete",
        data: {}
      }
    end
  end

  # Playback tools

  def play_original_audio
    entry = @session.current_entry
    return { text: "No segment selected.", action: "none", data: {} } unless entry

    {
      text: "Playing the original recording.",
      action: "play_original",
      data: { entry_id: entry.id }
    }
  end

  def play_irish_transcription
    entry = @session.current_entry
    return { text: "No segment selected.", action: "none", data: {} } unless entry

    {
      text: "Here's the transcription.",
      action: "play_transcription",
      data: { entry_id: entry.id, irish_text: entry.word_or_phrase }
    }
  end

  def play_english_translation
    entry = @session.current_entry
    return { text: "No segment selected.", action: "none", data: {} } unless entry

    {
      text: entry.translation.presence || "No translation available yet.",
      action: "play_translation",
      data: { entry_id: entry.id, english_text: entry.translation }
    }
  end

  def play_surrounding_context(before_count, after_count)
    entry = @session.current_entry
    recording = @session.voice_recording
    return { text: "No segment selected.", action: "none", data: {} } unless entry && recording

    entries = recording.dictionary_entries.order(:region_start)
    current_idx = entries.find_index(entry)

    start_idx = [current_idx - before_count, 0].max
    end_idx = [current_idx + after_count, entries.size - 1].min

    context_entries = entries[start_idx..end_idx]
    context_text = context_entries.map(&:word_or_phrase).join(" ... ")

    {
      text: "Here's the context around this segment.",
      action: "play_context",
      data: {
        entries: context_entries.map { |e| { id: e.id, irish: e.word_or_phrase, english: e.translation } },
        context_irish_text: context_text
      }
    }
  end

  # Search and selection tools

  def search_recordings(query)
    results = VoiceRecording.search_by_metadata(query).limit(5)

    if results.empty?
      { text: "I couldn't find any recordings about #{query}. Try something else?", action: "none", data: {} }
    elsif results.one?
      recording = results.first
      @session.start_recording!(recording)
      entry = @session.current_entry
      {
        text: "Found #{recording.title}. Starting with the first segment.",
        action: "play_transcription",
        data: { entry_id: entry&.id, irish_text: entry&.word_or_phrase }
      }
    else
      @session.store_context("search_results", results.pluck(:id, :title))
      titles = results.map.with_index { |r, i| "#{i + 1}: #{r.title}" }.join(". ")
      {
        text: "I found #{results.size} recordings. #{titles}. Which one would you like?",
        action: "await_selection",
        data: { results: results.pluck(:id, :title) }
      }
    end
  end

  def select_recording(recording_id)
    recording = VoiceRecording.find_by(id: recording_id)
    return { text: "I couldn't find that recording.", action: "none", data: {} } unless recording

    @session.start_recording!(recording)
    entry = @session.current_entry

    {
      text: "Starting #{recording.title}.",
      action: "play_transcription",
      data: { entry_id: entry&.id, irish_text: entry&.word_or_phrase }
    }
  end

  # Correction tools

  def update_transcription(corrected_text)
    entry = @session.current_entry
    return { text: "No segment selected.", action: "none", data: {} } unless entry

    entry.update!(word_or_phrase: corrected_text)

    {
      text: "Updated the transcription to: #{corrected_text}. Is that correct?",
      action: "play_transcription",
      data: { entry_id: entry.id, irish_text: corrected_text }
    }
  end

  def update_translation(corrected_text)
    entry = @session.current_entry
    return { text: "No segment selected.", action: "none", data: {} } unless entry

    entry.update!(translation: corrected_text)

    {
      text: "Updated the translation to: #{corrected_text}.",
      action: "none",
      data: {}
    }
  end

  # Tool definitions for OpenAI

  def tool_definitions
    [
      # Navigation
      {
        type: "function",
        function: {
          name: "confirm_entry",
          description: "Confirm the current transcription and translation are correct, then move to next segment. Use when user says 'confirmed', 'correct', 'yes that's right', 'good', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "next_entry",
          description: "Move to the next segment without confirming. Use when user says 'next', 'move on', 'next one', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "skip_entry",
          description: "Skip this segment (don't confirm) and move to the next. Use when user says 'skip', 'pass', 'I don't know this one', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },

      # Playback
      {
        type: "function",
        function: {
          name: "play_original",
          description: "Play the original audio recording of the current segment. Use when user says 'play the original', 'play the audio', 'let me hear it again', 'play the Irish', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "play_transcription",
          description: "Speak the Irish transcription using text-to-speech. Use when user says 'read the transcription', 'say it', 'play the transcription', 'speak the Irish', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "play_translation",
          description: "Speak the English translation. Use when user says 'what does it mean', 'play the translation', 'say it in English', 'translate', etc.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "play_context",
          description: "Play surrounding segments for context. Use when user says 'I need more context', 'play what comes before', 'play around it', etc.",
          parameters: {
            type: "object",
            properties: {
              entries_before: { type: "integer", description: "Number of entries before current to include", default: 1 },
              entries_after: { type: "integer", description: "Number of entries after current to include", default: 1 }
            },
            required: []
          }
        }
      },

      # Search and selection
      {
        type: "function",
        function: {
          name: "search_recordings",
          description: "Search for voice recordings by topic, location, or content. Use when user asks to find recordings about something.",
          parameters: {
            type: "object",
            properties: {
              query: { type: "string", description: "Search query - topics like 'fishing', 'farming', locations, speaker names, etc." }
            },
            required: ["query"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "select_recording",
          description: "Select a specific recording to work on. Use when user chooses from search results.",
          parameters: {
            type: "object",
            properties: {
              recording_id: { type: "integer", description: "The ID of the recording to select" }
            },
            required: ["recording_id"]
          }
        }
      },

      # Corrections
      {
        type: "function",
        function: {
          name: "update_transcription",
          description: "Update the Irish transcription with a correction. Use when user provides a corrected Irish text or spells out a word.",
          parameters: {
            type: "object",
            properties: {
              corrected_text: { type: "string", description: "The corrected Irish transcription" }
            },
            required: ["corrected_text"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "update_translation",
          description: "Update the English translation with a correction. Use when user provides a corrected English translation.",
          parameters: {
            type: "object",
            properties: {
              corrected_text: { type: "string", description: "The corrected English translation" }
            },
            required: ["corrected_text"]
          }
        }
      }
    ]
  end

  def system_prompt
    <<~PROMPT
      You are a voice assistant for Abairt, helping native Irish speakers review and correct transcriptions.
      Users interact entirely by voice - they may be elderly and have difficulty with screens.

      Current state:
      #{current_context}

      Your job:
      1. Help users find recordings (by topic, location, or random)
      2. Navigate through segments: confirm, next, skip
      3. Play audio: original recording, Irish transcription (TTS), English translation
      4. Handle corrections conversationally - if spelling is unclear, ask them to spell it

      Use the available tools to perform actions. Respond conversationally in English.
      Keep responses SHORT and clear - they will be spoken aloud.

      When a user provides a correction, use update_transcription or update_translation.
      If you're unsure what they said, ask them to repeat or spell it out.
    PROMPT
  end

  def current_context
    parts = []

    if @session.voice_recording
      vr = @session.voice_recording
      parts << "Recording: #{vr.title}"
      parts << "Summary: #{vr.summary}" if vr.summary.present?
      parts << "Total segments: #{vr.dictionary_entries.count}"
    else
      parts << "No recording selected yet"
    end

    if @session.current_entry
      entry = @session.current_entry
      pos = entry_position
      parts << "Segment #{pos} of #{@session.voice_recording.dictionary_entries.count}"
      parts << "Irish: #{entry.word_or_phrase}"
      parts << "English: #{entry.translation}" if entry.translation.present?
      parts << "Status: #{entry.accuracy_status}"
    end

    parts.join("\n")
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

  def error_response(text)
    Response.new(text: text, action: "none", data: {}, speak_english: text)
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )
  end
end
