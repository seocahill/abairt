# frozen_string_literal: true

# A question is recorded before it is addressed to anyone.
#
# The speaker used to be chosen when the learner pressed record, which meant
# nothing could be recorded at all until somebody was connected, and the choice
# was already stale by the time the question actually went out. It is now
# chosen as the question is delivered, so a recording made with nobody
# connected waits in the queue and reaches the first speaker who arrives.
#
# SQLite rebuilds the table to drop a NOT NULL. There are no triggers on
# questions — unlike users — so there is nothing here to recreate afterwards.
class AllowQuestionsWithoutASpeaker < ActiveRecord::Migration[8.1]
  def change
    change_column_null :questions, :speaker_id, true
  end
end
