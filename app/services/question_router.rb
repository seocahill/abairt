# frozen_string_literal: true

# Chooses which speaker a new question goes to.
#
#   QuestionRouter.new.speaker
#
# With one speaker this is simply that speaker. It picks whoever has the
# shortest backlog so that adding a second person needs no other change — and
# so nobody quietly accumulates a queue they will never get through.
class QuestionRouter
  UNANSWERED = %w[waiting sent].freeze

  def speaker
    User.answering
      .left_joins(:asked_questions)
      .where(questions: {status: [nil, *Question.statuses.values_at(*UNANSWERED)]})
      .group("users.id")
      .order(Arel.sql("COUNT(questions.id) ASC"))
      .first
  end
end
