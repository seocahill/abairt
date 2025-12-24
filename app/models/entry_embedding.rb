class EntryEmbedding

  attr_reader :client

  def initialize
    @llm = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.dig(:openai, :openai_key),  default_options: {
      chat_completion_model_name: "gpt-4.1", completion_model_name: "gpt-4.1"
    })
    @connection_string = Rails.env.production? ? Rails.application.credentials.dig(:vector_db_url) : "postgres://postgres@localhost:5432/postgres"
  end

  def load(client, filepath)
    my_pdf = Rails.root.join(filepath)
    client.add_data(paths: [my_pdf], options: { chunk_size: 8191 } )
  end

  def list_grammatic_forms(sentence="he is hitting me")
    prompt = "List every syntactically correct way you can say the following in the Irish Language: '#{sentence} and return each possible way in Irish only.'"
    client = Langchain::Vectorsearch::Pgvector.new(
      url: @connection_string,
      index_name: 'grammar',
      llm: @llm
    )
    client.ask(question: prompt).raw_response.dig("choices", 0, "message", "content")
  end

  def list_idioms(sentence="it's raining really heavily")
    prompt = "list any Irish Language idioms you know that can be used in place of the following: '#{sentence}'. Include a literal translation in English with each Irish idiom in the list or results."
    client = Langchain::Vectorsearch::Pgvector.new(
      url: @connection_string,
      index_name: 'idioms',
      llm: @llm
    )
    client.ask(question: prompt).raw_response.dig("choices", 0, "message", "content")
  end
end
