namespace :peaks do
  desc "Queue waveform peak generation for recordings without usable peaks (only fills the peaks column)"
  task backfill: :environment do
    VoiceRecording.find_each do |recording|
      next if recording.peaks_ready?

      GeneratePeaksJob.perform_later(recording.id)
    end
  end
end
