# frozen_string_literal: true

module DictionaryEntries
  # Returns (and lazily creates) a ClonedAudioRendition for a given
  # DictionaryEntry + voice user. The first request enqueues rendering and
  # returns 202; subsequent requests return the rendition's media URL when
  # ready.
  class ClonedRenditionsController < ApplicationController
    before_action :set_entry
    before_action :set_voice_user

    def show
      rendition = ClonedAudioRendition.find_by(
        voice_user: @voice_user,
        source: @entry
      )

      if rendition&.ready? && rendition.media.attached?
        render json: {status: "ready", audioUrl: url_for(rendition.media)}
      elsif rendition&.failed?
        render json: {status: "failed", error: rendition.error_message}, status: :unprocessable_entity
      elsif rendition
        render json: {status: "pending"}, status: :accepted
      else
        rendition = ClonedAudioRendition.create!(
          voice_user: @voice_user,
          source: @entry,
          status: :pending
        )
        RenderClonedRenditionJob.perform_later(rendition.id)
        render json: {status: "pending"}, status: :accepted
      end
    end

    private

    def set_entry
      @entry = DictionaryEntry.find(params[:dictionary_entry_id])
      authorize @entry, :show?
    end

    def set_voice_user
      @voice_user = User.with_cloned_voice.find(params[:voice_user_id])
    end
  end
end
