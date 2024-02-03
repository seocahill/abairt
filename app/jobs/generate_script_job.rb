class GenerateScriptJob < ApplicationJob
  queue_as :default

  def perform(word_list, script_type)
    word_list.generate_script(script_type)
    word_list.save
    Turbo::StreamsChannel.broadcast_replace_to(
      "word_lists/#{word_list.id}",
      target: "script",
      partial: "word_lists/script",
      locals: { word_list: @word_list }
    )
  end
end
