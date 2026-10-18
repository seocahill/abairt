# frozen_string_literal: true

# One person checks a recording through, start to finish.
#
# Context accumulates as you listen — the speaker's habits, the recurring
# townlands, who "he" keeps meaning — and none of it transfers. Split a
# recording between two people and each re-solves the same puzzles, and their
# spelling judgements diverge invisibly. So a recording is claimed before it is
# worked on, and a claim is exclusive.
class AddClaimToVoiceRecordings < ActiveRecord::Migration[8.1]
  def change
    add_reference :voice_recordings, :claimed_by, foreign_key: {to_table: :users}
    add_column :voice_recordings, :claimed_at, :datetime
  end
end
