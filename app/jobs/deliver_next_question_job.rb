# frozen_string_literal: true

class DeliverNextQuestionJob < ApplicationJob
  queue_as :default

  def perform(speaker)
    QuestionQueue.new(speaker).deliver_next
  end
end
