# frozen_string_literal: true

# Cuts an entry's audio clip from its recording, once it has times (#133).
class EntryAudioSnippetJob < ApplicationJob
  queue_as :default

  def perform(entry)
    entry.create_audio_snippet unless entry.media.attached?
  end
end
