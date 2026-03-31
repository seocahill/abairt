module VoiceRecordings
  class SpeakersController < ApplicationController
    before_action :set_voice_recording

    def index
      authorize @voice_recording, :speakers?
      @temp_speakers = @voice_recording.users.where(role: :temporary)
      @speakers = User.speaker.order(:name)
      @analyzed_speakers = @voice_recording.analysis_speakers
      @new_speaker = User.new(role: :speaker, ability: :C2)
    end

    def search
      authorize @voice_recording, :speakers?
      query = params[:q].to_s.strip
      speakers = User.speaker.search(query).order(:name).limit(10)

      render json: speakers.map { |s| {id: s.id, name: s.name, dialect: s.dialect, ability: s.ability} }
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
