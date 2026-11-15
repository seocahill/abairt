# Additive only: raw ASR output kept beside entries, frozen evaluation sets and
# stored evaluation runs. Nothing existing is changed.
class CreateAsrEvaluationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :asr_hypotheses do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :model
      t.text :text, null: false
      t.timestamps
    end
    add_index :asr_hypotheses, [:dictionary_entry_id, :provider]

    create_table :asr_eval_sets do |t|
      t.string :name, null: false
      t.integer :version, null: false, default: 1
      t.datetime :frozen_at, null: false
      t.timestamps
    end
    add_index :asr_eval_sets, [:name, :version], unique: true

    create_table :asr_eval_set_entries do |t|
      t.references :asr_eval_set, null: false, foreign_key: true
      t.references :dictionary_entry, null: false, foreign_key: true
      t.timestamps
    end
    add_index :asr_eval_set_entries, [:asr_eval_set_id, :dictionary_entry_id], unique: true, name: "index_asr_eval_set_entries_uniqueness"

    create_table :asr_eval_runs do |t|
      t.references :asr_eval_set, null: false, foreign_key: true
      t.string :provider, null: false
      t.integer :entries_scored, null: false, default: 0
      t.json :results, null: false, default: {}
      t.timestamps
    end
  end
end
