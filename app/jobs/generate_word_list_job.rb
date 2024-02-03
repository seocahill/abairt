class GenerateWordListJob < ApplicationJob
  queue_as :default

  def perform(word_list)
    results = word_list.generate_vocab
    results.dig('vocabulary').each do |result|
      user = User.ai.first
      entry = DictionaryEntry.create(
        owner: user,
        speaker_id: user.id,
        word_or_phrase: result["irish_word_or_phrase"],
        translation: result["english_translation"]
      )
      word_list.dictionary_entries << entry
      Turbo::StreamsChannel.broadcast_append_to(
        "word_lists/#{word_list.id}",
        target: "dictionary_entries",
        partial: "word_lists/dictionary_entry",
        locals: { entry: entry, current_user: word_list.owner, list: word_list }
      )
    end
  end
end
