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
    @android_version = AndroidRelease.latest if android_version_enabled?
  end

  private

  def android_version_enabled?
    Flipper.enabled?(:f126_android_version, current_user)
  end
end
