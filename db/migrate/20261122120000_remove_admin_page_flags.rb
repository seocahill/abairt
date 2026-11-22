# Admin pages don't use flags (#184): /admin/asr and /admin/training_progress
# are always on for admins, so their flags leave the /flipper list.
class RemoveAdminPageFlags < ActiveRecord::Migration[8.1]
  def up
    Flipper.remove(:f75_asr_eval)
    Flipper.remove(:f142_training_progress)
  end

  def down
    Flipper.add(:f75_asr_eval)
    Flipper.add(:f142_training_progress)
  end
end
