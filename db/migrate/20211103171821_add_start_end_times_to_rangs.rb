class AddStartEndTimesToRangs < ActiveRecord::Migration[6.1]
  def change
    add_column :rangs, :start_time, :datetime
    add_column :rangs, :end_time, :datetime
  end
end
