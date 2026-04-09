namespace :backfill do
  desc "Enqueue TranscodeAudioTrackJob for all MP3 voice recordings without a CBR audio_track"
  task audio_tracks: :environment do
    recordings = VoiceRecording
      .joins(:media_attachment)
      .joins("JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id")
      .where(active_storage_blobs: { content_type: "audio/mpeg" })
      .where.not(id: VoiceRecording.joins(:audio_track_attachment).select(:id))

    total = recordings.count
    puts "Enqueueing TranscodeAudioTrackJob for #{total} recordings..."

    recordings.find_each.with_index(1) do |recording, i|
      TranscodeAudioTrackJob.perform_later(recording)
      print "." if i % 10 == 0
    end

    puts "\nDone — #{total} jobs enqueued."
  end
end
