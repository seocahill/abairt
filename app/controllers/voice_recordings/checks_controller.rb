# frozen_string_literal: true

module VoiceRecordings
  # Check mode (f140_check_mode): one unchecked line at a time, with its audio,
  # editable, and a single action that confirms it and moves on.
  #
  # Saving and confirming go through the same model and policies as the line
  # list: confirmed lines stay locked, and every save is a normal versioned update.
  class ChecksController < ApplicationController
    before_action :ensure_flag_enabled
    before_action :set_voice_recording
    before_action :set_queue

    def show
      authorize @voice_recording, :check?
      @entry = @queue.current(params[:entry_id])
      return unless @entry

      @following = @queue.following(@entry)
      @preceding = @queue.preceding(@entry)
    end

    def update
      authorize @voice_recording, :check?
      entry = @voice_recording.dictionary_entries.unconfirmed_accuracy.find_by(id: params[:entry_id])
      return redirect_to voice_recording_check_path(@voice_recording), alert: "That line has already been checked." unless entry

      authorize entry, :update?
      authorize entry, :confirm?

      # Two saves, as in the line list: the text, then the confirmation.
      if entry.update(entry_params.merge(translator_id: current_user.id)) && entry.update(accuracy_status: :confirmed)
        EmbedDictionaryEntryJob.perform_later(entry.id)
        redirect_to voice_recording_check_path(@voice_recording, entry_id: @queue.following(entry)&.id)
      else
        redirect_to voice_recording_check_path(@voice_recording, entry_id: entry.id), alert: entry.errors.full_messages.to_sentence
      end
    end

    private

    def entry_params
      params.require(:dictionary_entry).permit(:word_or_phrase, :translation)
    end

    def set_voice_recording
      @voice_recording = VoiceRecording.find(params[:voice_recording_id])
    end

    def set_queue
      @queue = CheckQueue.new(@voice_recording)
    end

    def ensure_flag_enabled
      raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f140_check_mode, current_user)
    end
  end
end
