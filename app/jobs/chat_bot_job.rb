class ChatBotJob < ApplicationJob
  queue_as :default

  def perform(question, rang)
    # required for broadcasting in development
    if Rails.env.development?
      ActiveStorage::Current.url_options = {
        host: 'localhost',
        port: 3000,
        protocol: 'http' # Optional if you're using HTTP in development. Use 'https' if necessary.
      }
    end

    # get the text from the user
    if question.media.attached?
      question.media.open do |file|
        text = question.transcribe_audio(file.path, 'ogg')
        question.update(word_or_phrase: text)
        Turbo::StreamsChannel.broadcast_replace_to(
          "rangs",
          target: "dictionary_entry_#{question.id}",
          partial: "rangs/message",
          locals: {
            message: question,
            current_user: question.speaker,
            current_day: question.updated_at.strftime("%d-%m-%y"),
            autoplay: false
          }
        )
      end
    end

    # generate a text response
    irish = question.chat_with_gpt(rang)
    new_entry = DictionaryEntry.create(speaker: rang.teacher, word_or_phrase: irish, translation: nil)

    # synth into gaelic
    new_entry.synthesize_text_to_speech_and_store if question.media.attached?

    # add to rang and broadcast
    rang.dictionary_entries << new_entry
    current_page_number = Pagy.new(count: rang.dictionary_entries.size, items: 20).last
    Turbo::StreamsChannel.broadcast_append_to("rangs",
      target: "paginate_page_#{current_page_number}",
      partial: "rangs/message",
      locals: { message: new_entry, current_user: rang.teacher, current_day: new_entry.updated_at.strftime("%d-%m-%y"), autoplay: true })
  end
end
