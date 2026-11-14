# Registers the flag, switched off, so it shows in the /flipper list.
class AddF82MomentLinksFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f82_moment_links)
  end

  def down
    Flipper.remove(:f82_moment_links)
  end
end
