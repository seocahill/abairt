class AddTimeToRang < ActiveRecord::Migration[6.1]
  def change
    add_column :rangs, :time, :datetime
  end
end
