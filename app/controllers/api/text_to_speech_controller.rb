class Api::TextToSpeechController < ApplicationController
  def create
    authorize DictionaryEntry
    entry = DictionaryEntry.new(word_or_phrase: params[:text])
    service = SynthesizeTextToSpeechService.new(entry)

    begin
      audio_content = service.process
      render json: { audioContent: audio_content }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
