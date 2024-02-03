class AddIntervalToLearningProgress < ActiveRecord::Migration[7.0]
  def change
    add_column :learning_progresses, :interval, :integer, null: false, default: 0
  end
end
