# Registers the flag, switched off, so it shows in the /flipper list.
class AddF142TrainingProgressFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f142_training_progress)
  end

  def down
    Flipper.remove(:f142_training_progress)
  end
end
