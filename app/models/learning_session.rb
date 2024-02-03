class LearningSession < ApplicationRecord
  belongs_to :user
  belongs_to :learnable, polymorphic: true

  has_many :learning_progresses, dependent: :destroy


  def name
    if learnable_type == "WordList"
      learnable.name
    else
      learnable.title
    end
  end

  # Returns the current learning progress or creates a new one if needed
  def current_or_new_learning_progress(current_item_id = nil)
    # Attempt to find the last incomplete learning progress
    entry = learnable.dictionary_entries
             .left_outer_joins(:learning_progresses)
             .where(learning_progresses: { id: nil })
             .first

    return self.learning_progresses.create(dictionary_entry: entry) if entry

    learning_progresses.where("next_review_date <= ?", Date.today)
                                        .where(completed: false)
                                        .order(next_review_date: :asc)
                                        .first

  end
end
