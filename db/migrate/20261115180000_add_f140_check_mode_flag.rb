# Registers the flag, switched off, so it shows in the /flipper list.
class AddF140CheckModeFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f140_check_mode)
  end

  def down
    Flipper.remove(:f140_check_mode)
  end
end
