# frozen_string_literal: true

# A question a learner asks a native speaker.
#
# The speaker's whole interface is WhatsApp: a voice note arrives, they hold the
# mic button and reply. Nothing else is ever asked of them. That is only
# workable because they are never holding more than one question at a time —
# see QuestionQueue — which is also what lets an incoming reply be matched to a
# question without ids, keywords or quoting.
class Question < ApplicationRecord
  belongs_to :asker, class_name: "User"
  belongs_to :speaker, class_name: "User"

  has_one_attached :audio
  has_one_attached :answer_audio

  # draft -> waiting -> sent -> answered. A recording stays a draft until the
  # learner has listened back and sent it; only then does it join the queue.
  enum :status, {draft: 0, waiting: 1, sent: 2, answered: 3}

  validates :audio, presence: true
  validate :speaker_answers_questions, on: :create

  scope :oldest_first, -> { order(created_at: :asc) }

  # Joins the queue. Returns false if it is not a draft, so a double tap or a
  # replayed request cannot queue the same recording twice.
  def send_to_speaker!
    return false unless draft?

    update!(status: :waiting)
  end

  def mark_sent!(wa_message_id)
    update!(status: :sent, sent_at: Time.current, wa_question_message_id: wa_message_id)
  end

  private

  def speaker_answers_questions
    return if speaker.nil? || speaker.answers_questions?

    errors.add(:speaker, "is not taking questions")
  end
end
