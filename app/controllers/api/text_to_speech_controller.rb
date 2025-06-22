class Api::TextToSpeechController < ApplicationController
  def create
    authorize DictionaryEntry
    
    # If entry_id is provided, use that specific entry
    if params[:entry_id].present?
      entry = DictionaryEntry.find(params[:entry_id])
      
      # Check if already has media
      if entry.media.attached?
        render json: { 
          audioUrl: url_for(entry.media),
          cached: true 
        }
        return
      end
      
      # Generate and attach audio to this entry
      service = SynthesizeTextToSpeechService.new(entry)
      audio_content = service.process
      
      render json: { 
        audioUrl: url_for(entry.media),
        cached: false,
        audioContent: audio_content # Keep for backward compatibility
      }
    else
      # No entry_id provided - temporary TTS (existing behavior)
      entry = DictionaryEntry.new(word_or_phrase: params[:text])
      service = SynthesizeTextToSpeechService.new(entry)
      audio_content = service.process
      
      render json: { audioContent: audio_content }
    end
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
