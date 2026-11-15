# Registers the flag, switched off, so it shows in the /flipper list.
class AddF125EarlyPlayFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f125_early_play)
  end

  def down
    Flipper.remove(:f125_early_play)
  end
end
