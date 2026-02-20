# frozen_string_literal: true

class AddLocationToUsersAndVoiceRecordings < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :location
    add_reference :voice_recordings, :location

    # Add analysis metadata to voice_recordings
    add_column :voice_recordings, :metadata_analysis, :json
  end
end
