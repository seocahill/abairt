# frozen_string_literal: true

class AutoTagService
  def initialize(dictionary_entry)
    @dictionary_entry = dictionary_entry
  end

  def process
    client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org))

    context =  "You are an Irish language translator. You take words and phrases and tag them using the following schema: Abstract nouns; Activities; Adjectives; Adverbs; Amount; Animals; Arguments; Astronomy; Buildings; Calendar & Seasons; Clothes; Colours; Comparatives; Conversation; Countryside; Disaster; Everyday phrases; Facial expressions; Farming life ; Feelings; Folklore; Food and drink; Games; Geographical terms; Grammar; Greetings; Health; Idioms; Interjections; Language; Life & death; Likes & dislikes; Measurement; Money; Music; Noise and sounds; Numbers; Objects; Past participle; People; Personality; Physical contact; Physical descriptions; Place names; Plants; Prepositions; Pronouns; Proverbs; Reduplication; Relationships; Religion; Rest and relaxation; School; Seashore wildlife; Shapes; Similes; Smells; Terms of endearment; The body; The city; The family; The home; The seashore; Timber; Time; To be able to; Toys; Transport; Verbs; Weather; Work. Choose up to five appropriate tags."

    prompt = "Please analyze the following phrase and generate tags for it. The results you return should be a single array of the tags you have chosen, nothing else. Phrase: #{@dictionary_entry.translation}"

    response = client.chat(parameters: {
      model: "gpt-4o-mini",  # or use the appropriate model you have access to
      messages: [
        { "role": "system", "content": context },
        { "role": "user", "content": prompt }
      ]
    })
    @dictionary_entry.tag_list = JSON.parse(response.dig('choices', 0, 'message', 'content'))
    @dictionary_entrysave
  end
end
