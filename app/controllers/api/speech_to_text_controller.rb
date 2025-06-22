module Api
  class SpeechToTextController < ApplicationController
    # Skip CSRF protection for API endpoints
    skip_before_action :verify_authenticity_token

    def create
      authorize Chat
      # Check if audio file is provided
      unless params[:audio].present?
        render json: { error: 'Audio file is required' }, status: :bad_request
        return
      end

      # Process the audio file
      result = SpeechToTextService.new(params[:audio]).transcribe

      if result[:transcript].present?
        # Add the transcription to the chat if chat_id is provided
        if params[:chat_id].present?
          add_transcription_to_chat(params[:chat_id], result[:transcript], result[:translation], result[:language])
        end

        render json: {
          transcript: result[:transcript],
          translation: result[:translation],
          language: result[:language]
        }
      else
        render json: { error: 'Failed to transcribe audio' }, status: :unprocessable_entity
      end
    end

    private

    def add_transcription_to_chat(chat_id, transcript, translation, language)
      begin
        chat = current_user.language_learning_chats.find(chat_id)

        # The phone call controller will handle adding the message through the chat controller
        # We're just logging it here for reference
        Rails.logger.info("Speech transcription for chat #{chat_id}: #{transcript}")
        if language == 'ga'
          Rails.logger.info("Translation: #{translation}")
        end
      rescue ActiveRecord::RecordNotFound
        Rails.logger.error("Chat not found for transcription logging: #{chat_id}")
      end
    end
  end
end
