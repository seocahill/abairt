# frozen_string_literal: true

module Api
  # Questions asked from other apps, such as the Mayo Irish course, on behalf
  # of their learners. The API user is the asker; asker_label says who actually
  # asked. There is no draft step: the app has already let the learner listen
  # back, so a question is sent as soon as it is created.
  #
  # Asking is open to whoever QuestionPolicy allows, as on the web.
  class QuestionsController < BaseController
    MAX_AUDIO_BYTES = 10.megabytes

    # Looking a question up is cheap and apps check for answers often; asking
    # spends a speaker's time, so it is the one held back.
    rate_limit to: 60, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }, only: :create, name: "ask"
    rate_limit to: 1000, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }, only: :show, name: "look_up"

    # POST /api/questions
    # Params:
    #   audio (required)       - the spoken question, any audio a browser records
    #   asker_label (optional) - who is asking, e.g. "philip, Mayo Irish course"
    def create
      question = current_api_user.questions.build(asked_via: "api", asker_label: params[:asker_label].to_s.squish.first(100).presence)
      return render(json: {error: "audio is required"}, status: :unprocessable_content) unless acceptable_audio?(params[:audio])
      return render(json: {error: "This account can't ask questions"}, status: :forbidden) unless QuestionPolicy.new(current_api_user, question).create?

      question.audio.attach(params[:audio])
      if question.save
        SendQuestion.new(question).call
        render json: serialize(question), status: :created
      else
        render json: {errors: question.errors.full_messages}, status: :unprocessable_content
      end
    end

    # GET /api/questions/:id
    def show
      render json: serialize(current_api_user.questions.find(params[:id]))
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Not found"}, status: :not_found
    end

    private

    def acceptable_audio?(file)
      file.respond_to?(:content_type) && file.content_type.to_s.match?(%r{\A(audio|video)/}) && file.size <= MAX_AUDIO_BYTES
    end

    def serialize(question)
      {
        id: question.id,
        status: question.status,
        asker_label: question.asker_label,
        created_at: question.created_at,
        sent_at: question.sent_at,
        answered_at: question.answered_at,
        audio_url: blob_url(question.audio),
        answer_audio_url: blob_url(question.answer_audio)
      }
    end

    def blob_url(attachment)
      rails_blob_url(attachment, protocol: request.protocol, host: request.host_with_port) if attachment.attached?
    end
  end
end
