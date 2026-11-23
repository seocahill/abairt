# Additive only (#133): a fresh ASR run of a recording is kept beside the
# current entries as candidates for a person to accept or dismiss. Nothing
# existing is changed.
class CreateTranscriptionRunsAndCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :transcription_runs do |t|
      t.references :voice_recording, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: {to_table: :users}
      t.string :fotheidil_video_id
      t.integer :status, null: false, default: 0
      t.json :segments, null: false, default: []
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :transcription_runs, :fotheidil_video_id, unique: true

    create_table :transcription_candidates do |t|
      t.references :transcription_run, null: false, foreign_key: true, index: false
      t.references :dictionary_entry, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.decimal :region_start, null: false
      t.decimal :region_end, null: false
      t.string :region_id
      t.string :speaker_label
      t.text :word_or_phrase, null: false
      t.integer :status, null: false, default: 0
      t.references :resolved_by, foreign_key: {to_table: :users}
      t.datetime :resolved_at
      t.timestamps
    end
    # One candidate per current entry in a run; new segments have no entry.
    add_index :transcription_candidates, [:transcription_run_id, :dictionary_entry_id], unique: true, name: "index_transcription_candidates_on_run_and_entry"
  end
end
