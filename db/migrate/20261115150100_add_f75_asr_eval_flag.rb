# Registers the flag, switched off, so it shows in the /flipper list.
class AddF75AsrEvalFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f75_asr_eval)
  end

  def down
    Flipper.remove(:f75_asr_eval)
  end
end
