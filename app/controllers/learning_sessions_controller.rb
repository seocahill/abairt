class LearningSessionsController < ApplicationController

  def show
    @learning_session = LearningSession.find(params[:id])
    authorize @learning_session

    if @learning_progress = @learning_session.current_or_new_learning_progress

      # Redirect to LearningProgress show view
      redirect_to @learning_progress
    else
      redirect_to root_path, notice: "Nothing to learn today"
    end
  end

  def index
    #   **Speaking Time**: 150-210 hours, est 60sec average audio per chat == 9000 chats
    #   **Estimated Number of Transcriptions to Understand**: 500-700
    #   **Vocabulary Size**: Around 3500-5000 words.
    authorize LearningSession
    @user = current_user
    @vocab_progress_count = current_user.learning_progresses
                              .joins(:learning_session)
                              .where(learning_sessions: { learnable_type: 'WordList' }, completed: true)
                              .size

    @vocab_progress = @vocab_progress_count
                              .fdiv(3500) * 100
                              .round

    @listening_progress_count = current_user.learning_progresses
                                  .joins(:learning_session)
                                  .where(learning_sessions: { learnable_type: 'VoiceRecording' }, completed: true)
                                  .size
    @listening_progress = @listening_progress_count
                                  .fdiv(700) * 100
                                  .round

    @speaking_progress_count = current_user.chats.with_attached_media.size
    @speaking_progress = @speaking_progress_count.fdiv(9000).*(100).round

    @pagy, @learning_sessions = pagy(current_user.learning_sessions, items: PAGE_SIZE)
  end

  def create
    @word_list = params[:learnable].constantize.find(params[:word_list_id])
    @learning_session = LearningSession.where(user: current_user, learnable: @word_list).first_or_create

    authorize @learning_session

    # Redirect to the LearningSession show action
    redirect_to @learning_session
  end
end
