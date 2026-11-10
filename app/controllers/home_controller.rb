class HomeController < ApplicationController
  skip_after_action :verify_authorized

  def index
    @pins = User.where(role: [:speaker, :teacher]).pins
    @stats = {
      recordings: VoiceRecording.count,
      speakers: User.speaker.count,
      phrases: DictionaryEntry.where.not(speaker_id: nil).count,
      with_audio: DictionaryEntry.has_recording.count
    }
  end
end
