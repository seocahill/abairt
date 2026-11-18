# Registers the flag, switched off, so it shows in the /flipper list.
class AddF170SearchToMomentFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f170_search_to_moment)
  end

  def down
    Flipper.remove(:f170_search_to_moment)
  end
end
