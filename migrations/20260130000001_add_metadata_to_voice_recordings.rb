# frozen_string_literal: true

class AddMetadataToVoiceRecordings < ActiveRecord::Migration[8.0]
  def change
    add_column :voice_recordings, :metadata, :json, default: {}
    add_column :voice_recordings, :metadata_extracted_at, :datetime
  end
end
