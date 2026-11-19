# Registers the flag, switched off, so it shows in the /flipper list.
class AddF172PlacePagesFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f172_place_pages)
  end

  def down
    Flipper.remove(:f172_place_pages)
  end
end
