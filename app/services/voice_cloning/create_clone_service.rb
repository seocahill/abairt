# frozen_string_literal: true

module VoiceCloning
  # Creates an Instant Voice Clone in ElevenLabs from a speaker's existing
  # DictionaryEntry audio. The chosen samples are concatenated with ffmpeg
  # and uploaded; the resulting voice_id is persisted on the User.
  class CreateCloneService
    MAX_SAMPLE_DURATION = 240.0 # seconds of concatenated audio to upload
    MIN_SAMPLES = 3
    MAX_SAMPLES = 25

    class Error < StandardError; end

    def initialize(user, client: nil)
      @user = user
      @client = client || ElevenLabs::Client.new
    end

    def call
      raise Error, "user already has a cloned voice" if @user.cloned_voice?

      entries = candidate_entries
      raise Error, "not enough audio samples for #{@user.name}" if entries.size < MIN_SAMPLES

      @user.update!(voice_clone_status: :pending, voice_clone_error: nil)

      sample_paths = []
      Dir.mktmpdir("voice_clone_#{@user.id}_") do |dir|
        sample_paths = build_sample_files(entries, dir)
        voice_id = @client.add_voice(
          name: voice_name,
          sample_paths: sample_paths,
          description: voice_description,
          labels: {dialect: @user.dialect.to_s, source: "abairt"}
        )

        @user.update!(
          cloned_voice_id: voice_id,
          voice_clone_status: :ready,
          voice_clone_provider: "elevenlabs",
          voice_cloned_at: Time.current,
          voice_clone_error: nil
        )
      end

      @user
    rescue => e
      @user.update(voice_clone_status: :failed, voice_clone_error: e.message)
      raise
    end

    private

    def candidate_entries
      DictionaryEntry
        .where(speaker_id: @user.id, accuracy_status: 1)
        .joins(:media_attachment)
        .limit(MAX_SAMPLES)
    end

    def build_sample_files(entries, dir)
      total = 0.0
      paths = []

      entries.each_with_index do |entry, idx|
        break if total >= MAX_SAMPLE_DURATION

        path = File.join(dir, "sample_#{idx}.mp3")
        entry.media.open do |blob|
          FileUtils.cp(blob.path, path)
        end

        duration = sample_duration(path)
        next if duration && duration < 1.0

        paths << path
        total += duration || 1.0
      end

      raise Error, "no usable samples after filtering" if paths.empty?

      paths
    end

    def sample_duration(path)
      output = `ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 #{Shellwords.escape(path)} 2>/dev/null`
      Float(output.strip)
    rescue ArgumentError, TypeError
      nil
    end

    def voice_name
      "Abairt - #{@user.name} (##{@user.id})"
    end

    def voice_description
      "Cloned voice for #{@user.name}. Dialect: #{@user.dialect}."
    end
  end
end
