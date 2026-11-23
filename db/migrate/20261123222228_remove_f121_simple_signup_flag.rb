# Simple sign-up and the profile password link are now always on (#121), so
# the flag leaves the /flipper list.
class RemoveF121SimpleSignupFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.remove(:f121_simple_signup)
  end

  def down
    Flipper.add(:f121_simple_signup)
  end
end
