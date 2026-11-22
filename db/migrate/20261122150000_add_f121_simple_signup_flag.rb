# Registers the flag, switched off, so it shows in the /flipper list.
class AddF121SimpleSignupFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f121_simple_signup)
  end

  def down
    Flipper.remove(:f121_simple_signup)
  end
end
