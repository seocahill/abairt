class ImportTranscriptionJob < ApplicationJob
  queue_as :default

  def perform(voice_recording)
     llm = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.dig(:openai, :openai_key),  default_options: {
      chat_completion_model_name: "gpt-4-1106-preview", completion_model_name: "gpt-4-1106-preview"
    })
    voice_recording.transcription.split(/\.|\?|!/).each do |text|
      prompt_text = "translate this piece of irish text: '#{text}' into english. return the translation only, no other information is required. q"
      llm_response = llm.chat(prompt: prompt_text).completion
      voice_recording.dictionary_entries.create!(word_or_phrase: text, translation: llm_response, user_id: voice_recording.user_id)
    end
  end
end
