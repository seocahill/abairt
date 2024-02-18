class ImportTranscriptionJob < ApplicationJob
  queue_as :long_running

  def perform(voice_recording)
     llm = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.dig(:openai, :openai_key),  default_options: {
      chat_completion_model_name: "gpt-4-1106-preview",
      completion_model_name: "gpt-4-1106-preview"
    }, llm_options: {
      request_timeout: 20000
    })
    json_schema = {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "word_or_phrase": {
            "type": "string"
          },
          "translation": {
            "type": "string"
          }
        },
        "required": ["word_or_phrase", "translation"]
      }
    }
    parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
    prompt = Langchain::Prompt::PromptTemplate.new(template: "Take the following text and split into phrases.  Return each phrase with an english translation.\n{format_instructions}\nIrish Text: {text}", input_variables: ["text", "format_instructions"])
    prompt_text = prompt.format(text: voice_recording.transcription.gsub(/\s+/, ""), format_instructions: parser.get_format_instructions)
    llm_response = llm.chat(prompt: prompt_text).completion
    parser.parse(llm_response).dig('items').each do |item|
      voice_recording.dictionary_entries.create!(word_or_phrase: item['word_or_phrase'], translation: item['translation'], user_id: voice_recording.user_id, quality: :high)
    end
  end
end
