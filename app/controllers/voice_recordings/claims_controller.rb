# frozen_string_literal: true

module VoiceRecordings
  # Taking a recording to check through, and handing it back.
  #
  # Its own resource rather than a verb on the recording, in the same shape as
  # the other sub-resources here. A claim is exclusive: see VoiceRecording#claim
  # for why a recording is checked by one person start to finish.
  class ClaimsController < ApplicationController
    before_action :set_voice_recording

    def create
      authorize @voice_recording, :claim?

      if @voice_recording.claim(current_user)
        redirect_to @voice_recording, notice: "This recording is yours to check."
      else
        redirect_to @voice_recording,
          alert: "#{@voice_recording.claimed_by.name} is already working through this one."
      end
    end

    def destroy
      authorize @voice_recording, :release_claim?
      @voice_recording.release!

      redirect_to @voice_recording, notice: "Handed back. Somebody else can take it now."
    end

    private

    def set_voice_recording
      @voice_recording = VoiceRecording.find(params[:voice_recording_id])
    end
  end
end
