# frozen_string_literal: true

# A recording is a draft until the learner has heard it back and sent it.
# Nothing reaches a speaker — and, later, nothing costs credits — on the
# strength of a button released in a coat pocket.
#
# draft takes 0 so the lifecycle reads in order, which shifts the rest up by
# one. The column default is already 0 and stays there, so only the existing
# rows need moving: anyone running the branch locally has them under the old
# numbering.
class AddDraftStatusToQuestions < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE questions SET status = status + 1"
  end

  def down
    execute "UPDATE questions SET status = status - 1 WHERE status > 0"
  end
end
