# Registers the flag, switched off, so it shows in the /flipper list.
class AddF81ListeningControlsFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f81_listening_controls)
  end

  def down
    Flipper.remove(:f81_listening_controls)
  end
end
