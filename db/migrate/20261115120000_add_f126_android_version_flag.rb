# Registers the flag, switched off, so it shows in the /flipper list.
class AddF126AndroidVersionFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f126_android_version)
  end

  def down
    Flipper.remove(:f126_android_version)
  end
end
