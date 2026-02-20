# frozen_string_literal: true

class AddLocationToUsersAndVoiceRecordings < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :location, foreign_key: true
    add_reference :voice_recordings, :location, foreign_key: true

    # Add analysis metadata to voice_recordings
    add_column :voice_recordings, :metadata_analysis, :jsonb
  end
end
