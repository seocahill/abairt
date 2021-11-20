class AddMeetingIdToRang < ActiveRecord::Migration[6.1]
  def change
    add_column :rangs, :meeting_id, :string
  end
end
