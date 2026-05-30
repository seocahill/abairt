class Api::TextToSpeechController < ApplicationController
  def create
    authorize DictionaryEntry

    voice_user = find_voice_user

    # If entry_id is provided, use that specific entry
    if params[:entry_id].present?
      entry = DictionaryEntry.find(params[:entry_id])

      # Check if already has media (only when no cloned voice requested)
      if entry.media.attached? && voice_user.nil?
        render json: {
          audioUrl: url_for(entry.media),
          cached: true
        }
        return
      end

      # Generate and attach audio to this entry
      service = SynthesizeTextToSpeechService.new(entry, voice_user: voice_user)
      audio_content = service.process

      render json: {
        audioUrl: url_for(entry.media),
        cached: false,
        audioContent: audio_content # Keep for backward compatibility
      }
    else
      # No entry_id provided - temporary TTS (existing behavior)
      entry = DictionaryEntry.new(word_or_phrase: params[:text])
      service = SynthesizeTextToSpeechService.new(entry, voice_user: voice_user)
      audio_content = service.process

      render json: { audioContent: audio_content }
    end
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def find_voice_user
    return nil if params[:voice_user_id].blank?

    User.with_cloned_voice.find_by(id: params[:voice_user_id])
  end
end
