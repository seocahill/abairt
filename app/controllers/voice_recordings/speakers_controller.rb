module VoiceRecordings
  class SpeakersController < ApplicationController
    before_action :set_voice_recording

    def index
      authorize @voice_recording, :speakers?
      @temp_speakers = @voice_recording.users.where(role: :temporary)
      @speakers = User.active

      # Search existing speakers
      @speakers = User.speaker
      @speakers = @speakers.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
      @speakers = @speakers.where(dialect: params[:dialect]) if params[:dialect].present?
      @speakers = @speakers.where("lat_lang && ?", params[:location]) if params[:location].present?

      @new_speaker = User.new(role: :speaker)
    end

    def update
      authorize @voice_recording, :speakers?
      @temp_speaker = User.find(params[:id])
      @new_speaker = User.find(params[:speaker_id])
      DictionaryEntry.transaction do
        DictionaryEntry
          .where(voice_recording: @voice_recording)
          .where(speaker: @temp_speaker)
          .update_all(speaker_id: @new_speaker.id)
      end

      redirect_to voice_recording_speakers_path(@voice_recording), notice: 'Speaker updated successfully'
    end

    private

    def set_voice_recording
      @voice_recording = VoiceRecording.find(params[:voice_recording_id])
    end
  end
end
