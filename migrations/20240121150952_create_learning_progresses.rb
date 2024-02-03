class CreateLearningProgresses < ActiveRecord::Migration[7.0]
  def change
    create_table :learning_progresses do |t|
      t.integer :repetition_number, null: false, default: 0
      t.float :ease_factor, null: false, default: 0.0
      t.date :next_review_date
      t.date :last_review_date
      t.integer :quality_of_last_review
      t.references :learning_session, null: false, foreign_key: true
      t.references :dictionary_entry, null: false, foreign_key: true

      t.timestamps
    end
  end
end
