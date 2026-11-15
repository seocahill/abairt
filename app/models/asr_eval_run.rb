# frozen_string_literal: true

class AsrEvalRun < ApplicationRecord
  belongs_to :asr_eval_set

  validates :provider, presence: true
  validates :entries_scored, numericality: {greater_than_or_equal_to: 0}
end
