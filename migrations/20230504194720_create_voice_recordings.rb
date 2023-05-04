class CreateVoiceRecordings < ActiveRecord::Migration[6.1]
  def change
    create_table :voice_recordings do |t|
      t.string :title
      t.text :description

      t.timestamps
    end
  end
end
