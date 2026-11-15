# frozen_string_literal: true

# A frozen, versioned list of entries used as ASR ground truth. Membership is
# chosen once from DictionaryEntry.asr_eval_candidates and then never changes;
# a new selection is a new version.
class AsrEvalSet < ApplicationRecord
  has_many :asr_eval_set_entries, dependent: :destroy
  has_many :dictionary_entries, through: :asr_eval_set_entries
  has_many :asr_eval_runs, dependent: :destroy

  validates :name, :frozen_at, presence: true
  validates :version, numericality: {only_integer: true, greater_than: 0}, uniqueness: {scope: :name}

  # Freezes the current candidates (or any given scope) as the next version.
  def self.freeze_from(name:, scope: DictionaryEntry.asr_eval_candidates)
    ids = scope.pluck(:id)
    transaction do
      set = create!(name: name, version: (where(name: name).maximum(:version) || 0) + 1, frozen_at: Time.current)
      ids.each { |id| set.asr_eval_set_entries.create!(dictionary_entry_id: id) }
      set
    end
  end

  def latest_run
    asr_eval_runs.order(created_at: :desc).first
  end
end
