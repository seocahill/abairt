class PostProcessEntryJob < ApplicationJob
  def perform(entry)
    entry.create_audio_snippet
    entry.translate
    entry.auto_tag
  end
end
