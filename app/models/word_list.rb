class WordList < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  # entries
  has_many :word_list_dictionary_entries, dependent: :destroy
  has_many :dictionary_entries, through: :word_list_dictionary_entries

  has_many :learning_sessions, as: :learnable

  has_many :user_lists, dependent: :destroy
  has_many :users, through: :user_lists

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << %w[front back audio]

      dictionary_entries.find_each do |entry|
        csv << [entry.word_or_phrase, entry.translation, entry.media.url]
      end
    end
  end

  def generate_vocab
    json_schema = {
      type: "object",
      properties: {
        vocabulary: {
          type: "array",
          items: {
            type: "object",
            properties: {
              irish_word_or_phrase: {
                type: "string",
                description: "An word or phrase in the Irish Language."
              },
              english_translation: {
                type: "string",
                description: "A translation into english of the irish word or phrase."
              }
            },
            required: ["irish_word_or_phrase", "english_translation"],
            additionalProperties: false
          },
          minItems: 1,
          maxItems: 50,
          description: "A vocabulary for a user defined context."
        }
      },
      required: ["vocabulary"],
      additionalProperties: false
    }
    parser = Langchain::OutputParsers::StructuredOutputParser.from_json_schema(json_schema)
    prompt = Langchain::Prompt::PromptTemplate.new(template: "You task is to generate a lexicon for this specific topic: {description}. Return a list comprising: 5 verbs, 4 adverbs, 20 nouns, 10 adjectives, 2 idioms, and 1 proverb. The language is Irish (Gaelic).\n{format_instructions}", input_variables: ["format_instructions", "description"])
    prompt_text = prompt.format(format_instructions: parser.get_format_instructions, description: description)
    llm = Langchain::LLM::OpenAI.new(api_key:Rails.application.credentials.dig(:openai, :openai_key),  default_options: {
      chat_completion_model_name: "gpt-4-1106-preview", completion_model_name: "gpt-4-1106-preview"
    })
    llm_response = llm.chat(prompt: prompt_text).completion
    parser.parse(llm_response)
  end

  def generate_script(type=monologue)
    prompt_text = <<-EOF
      The task is to develop a short, easy to memorize #{type} on this specific topic: #{description}.
      The goal is to give the Irish language learner rehearsed conversation to help them succeed when attempting to talk to a native speaker. This concept is called a 'language island' and was developed by the linguist Boris Shekhtman.
      It's important to keep the tone as conversational as possible.
      It's important to use the Irish dialect of Connacht. Don't use standard or Munster Irish if possible. You may use Ulster Irish.
      You can loosely base the script on the pre-generated lexicon of words for this topic:
      ```
      #{dictionary_entries.pluck(:word_or_phrase).join(', ')}
      ```
    EOF
    llm = Langchain::LLM::OpenAI.new(api_key:Rails.application.credentials.dig(:openai, :openai_key), default_options: {
      chat_completion_model_name: "gpt-4-1106-preview", completion_model_name: "gpt-4-1106-preview"
    })
    llm_response = llm.chat(prompt: prompt_text).completion
    self.script = llm_response
  end
end
