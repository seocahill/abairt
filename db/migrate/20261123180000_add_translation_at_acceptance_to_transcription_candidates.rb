# Additive only (#133): when a candidate's new Irish replaces an entry's text,
# the translation is kept as it was. Remembering that translation lets the
# entry say it may now be out of date, until somebody changes it.
class AddTranslationAtAcceptanceToTranscriptionCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :transcription_candidates, :translation_at_acceptance, :text
  end
end
