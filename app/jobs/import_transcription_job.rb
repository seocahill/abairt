class ImportTranscriptionJob < ApplicationJob
  queue_as :long_running

  def perform(voice_recording, speaker_id)
     llm = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.dig(:openai, :openai_key),  default_options: {
      chat_completion_model_name: "gpt-4-1106-preview",
      completion_model_name: "gpt-4-1106-preview"
    }, llm_options: {
      request_timeout: 2000
    })
    # Add dummy to start and end to ensure they are translated
    sentences = [""] + voice_recording.transcription.split(/(?<=[?.!])\s*/) + [""]
    sentences.each_cons(3) do |prev, current, next_sentence|
      prompt_text = <<-PROMPT
      Translate the following sentence from Irish to English, considering the context provided by the surrounding sentences.

      Previous sentence (for context): #{prev || "N/A"}
      Current sentence to translate: #{current}
      Next sentence (for context): #{next_sentence || "N/A"}

      Return just the translation as a string.
      PROMPT

      llm_response = llm.chat(prompt: prompt_text).completion
      Rails.logger.info("received response - #{llm_response}")
      voice_recording.dictionary_entries.create!(word_or_phrase: current, translation: llm_response, user_id: voice_recording.user_id, quality: :good, speaker_id: speaker_id)
    end
  end
end
