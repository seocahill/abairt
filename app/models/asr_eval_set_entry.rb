# frozen_string_literal: true

class AsrEvalSetEntry < ApplicationRecord
  belongs_to :asr_eval_set
  belongs_to :dictionary_entry

  validates :dictionary_entry_id, uniqueness: {scope: :asr_eval_set_id}
end
