# frozen_string_literal: true

class TranslationService
  def initialize(entry)
    @entry = entry
  end

   def translate
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: 'gpt-4.1',
      messages: [
        { role: "system", content: "You are an Irish (Gaeilge) to English translator. Provide only the direct translation, no additional commentary." },
        { role: "user", content: "Translate this Irish text to English: #{@entry.word_or_phrase}. If you are finding the dialect difficult to understand (North Connacht Irish), there is sometimes a standard Irish version available here also: #{@entry.standard_irish}." }
      ],
      temperature: 0.3,
    })

    translation = response.dig('choices', 0, 'message', 'content')
    return translation if translation.present?
  rescue => e
    Rails.logger.error("Translation failed: #{e.message}")
    nil
  end
end
