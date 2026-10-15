# frozen_string_literal: true

class QuestionMailer < ApplicationMailer
  def answered(question)
    @question = question
    @url = question_url(question)

    mail(to: question.asker.email, subject: "Tá freagra ar do cheist")
  end
end
