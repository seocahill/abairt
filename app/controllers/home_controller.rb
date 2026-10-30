class HomeController < ApplicationController
  skip_after_action :verify_authorized

  # Where learners go for structured lessons built on these recordings.
  COURSE_URL = ENV.fetch("MAYO_COURSE_URL", "https://mayo-irish-app.fly.dev")

  def index
    @pins = User.where(role: [:speaker, :teacher]).pins
    @course_url = COURSE_URL
    @stats = {
      recordings: VoiceRecording.count,
      speakers: User.speaker.count,
      phrases: DictionaryEntry.where.not(speaker_id: nil).count,
      with_audio: DictionaryEntry.has_recording.count
    }
  end
end
