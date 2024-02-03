class AddCompletedToLearningProgresses < ActiveRecord::Migration[7.0]
  def change
    add_column :learning_progresses, :completed, :boolean, null: false, default: false
  end
end
