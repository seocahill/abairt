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
      .group("users.id")
      .order(Arel.sql("COUNT(#{unanswered}) ASC"))
      .first
  end

  private

  # Counted in the ORDER BY rather than filtered in a WHERE. Filtering on the
  # joined table drops a speaker entirely once every one of their questions
  # fails the condition — so a speaker who had merely answered everything asked
  # of them, or who had an unsent draft, vanished and no question could be
  # routed at all.
  def unanswered
    statuses = Question.statuses.values_at(*UNANSWERED).join(", ")
    "CASE WHEN questions.status IN (#{statuses}) THEN 1 END"
  end
end
