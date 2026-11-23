# Registers the flag, switched off, so it shows in the /flipper list.
class AddF133RetranscribeFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f133_retranscribe)
  end

  def down
    Flipper.remove(:f133_retranscribe)
  end
end
