# Additive only (#133, step 5): a candidate can now be a timing proposal for a
# line that has none, so a run may hold one candidate per entry and kind; and a
# run remembers which current lines it did not hear in the new transcription.
class AddTimingAndUnheardToTranscriptionRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :transcription_runs, :unheard_entry_ids, :json, null: false, default: []

    remove_index :transcription_candidates, [:transcription_run_id, :dictionary_entry_id], unique: true, name: "index_transcription_candidates_on_run_and_entry"
    add_index :transcription_candidates, [:transcription_run_id, :dictionary_entry_id, :kind], unique: true, name: "index_transcription_candidates_on_run_entry_and_kind"
  end
end
