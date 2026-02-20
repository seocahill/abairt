# frozen_string_literal: true

module Admin
  class DataDashboardController < ApplicationController
    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      @corpus        = corpus_stats
      @quality       = quality_stats
      @training      = training_readiness
      @dialects      = dialect_stats
      @speakers      = top_speakers
      @gender        = gender_stats
      @locations     = location_stats
      @recent        = recent_analyses
    end

    private

    def corpus_stats
      total_entries    = DictionaryEntry.count
      entries_with_audio = DictionaryEntry.joins(:media_attachment).count
      total_seconds    = DictionaryEntry.sum("region_end - region_start")
      confirmed        = DictionaryEntry.where(accuracy_status: :confirmed).count
      total_recordings = VoiceRecording.count
      analyzed         = VoiceRecording.where.not(metadata_analysis: nil).count

      {
        total_recordings: total_recordings,
        analyzed_recordings: analyzed,
        analyzed_pct: pct(analyzed, total_recordings),
        total_entries: total_entries,
        entries_with_audio: entries_with_audio,
        audio_pct: pct(entries_with_audio, total_entries),
        confirmed_entries: confirmed,
        confirmed_pct: pct(confirmed, total_entries),
        total_hours: (total_seconds / 3600.0).round(1),
        total_speakers: User.where(role: :speaker).count,
        total_locations: Location.count
      }
    end

    def quality_stats
      rows = DictionaryEntry
        .joins(:media_attachment)
        .group(:quality)
        .select("quality, COUNT(*) as count, SUM(region_end - region_start) as seconds")
        .map { |r| [r.quality, { count: r.count, hours: (r.seconds.to_f / 3600).round(2) }] }
        .to_h

      total = rows.values.sum { |v| v[:count] }.to_f
      rows.transform_values { |v| v.merge(pct: pct(v[:count], total)) }
    end

    def training_readiness
      hq_seconds = DictionaryEntry
        .joins(:media_attachment)
        .where(quality: [:good, :excellent], accuracy_status: :confirmed)
        .sum("region_end - region_start")
      hq_hours = hq_seconds / 3600.0

      translated_phrases = DictionaryEntry
        .joins(:speaker)
        .where(users: { dialect: :tuaisceart_mhaigh_eo })
        .where(accuracy_status: :confirmed)
        .where.not(translation: [nil, ""])
        .count

      best_speaker_seconds = DictionaryEntry
        .joins(:media_attachment, :speaker)
        .where(quality: [:good, :excellent])
        .group(:speaker_id)
        .sum("region_end - region_start")
        .values.max.to_f
      best_speaker_hours = best_speaker_seconds / 3600.0

      {
        voice_cloning: {
          label: "Voice Cloning",
          ready: hq_hours >= 0.008, # 30 seconds
          hours: hq_hours.round(1),
          minimum: 0.008,
          ideal: 0.05,
          description: "Requires 30 sec of clean audio per voice"
        },
        asr: {
          label: "Speech Recognition (ASR)",
          ready: hq_hours >= 5,
          hours: hq_hours.round(1),
          minimum: 5,
          ideal: 20,
          description: "Requires 5–20 hrs of transcribed audio"
        },
        tts: {
          label: "Text-to-Speech (TTS)",
          ready: best_speaker_hours >= 5,
          hours: best_speaker_hours.round(1),
          minimum: 5,
          ideal: 20,
          description: "Requires 5–20 hrs from a single speaker"
        },
        dialect_ai: {
          label: "Dialect AI",
          ready: translated_phrases >= 1000,
          count: translated_phrases,
          minimum: 1000,
          ideal: 5000,
          description: "Requires 1,000–5,000 translated phrase pairs"
        }
      }
    end

    def dialect_stats
      rows = DictionaryEntry
        .joins(:speaker)
        .where.not(users: { dialect: nil })
        .group("users.dialect")
        .select("users.dialect, COUNT(*) as entry_count, SUM(dictionary_entries.region_end - dictionary_entries.region_start) as seconds")

      total_seconds = rows.sum(&:seconds).to_f

      rows.map do |r|
        {
          dialect: r.dialect.humanize,
          entries: r.entry_count,
          hours: (r.seconds.to_f / 3600).round(2),
          pct: pct(r.seconds.to_f, total_seconds)
        }
      end.sort_by { |r| -r[:hours] }
    end

    def top_speakers
      DictionaryEntry
        .joins(:speaker, :media_attachment)
        .where.not(users: { role: :temporary })
        .group("users.id", "users.name", "users.voice", "users.dialect", "users.ability")
        .select(
          "users.id, users.name, users.voice, users.dialect, users.ability,
           COUNT(dictionary_entries.id) as entry_count,
           SUM(dictionary_entries.region_end - dictionary_entries.region_start) as seconds,
           AVG(CASE dictionary_entries.quality WHEN 3 THEN 3 WHEN 2 THEN 2 WHEN 1 THEN 1 ELSE 0 END) as avg_quality"
        )
        .order("seconds DESC")
        .limit(15)
        .map do |r|
          {
            id: r.id,
            name: r.name.presence || "Speaker ##{r.id}",
            voice: r.voice,
            dialect: r.dialect&.humanize,
            ability: r.ability,
            entries: r.entry_count,
            hours: (r.seconds.to_f / 3600).round(2),
            tts_candidate: r.seconds.to_f / 3600 >= 5
          }
        end
    end

    def gender_stats
      rows = User
        .joins(:spoken_dictionary_entries)
        .where.not(role: :temporary)
        .group(:voice)
        .select("voice, COUNT(DISTINCT users.id) as speaker_count, SUM(dictionary_entries.region_end - dictionary_entries.region_start) as seconds")

      total = rows.sum(&:seconds).to_f

      rows.map do |r|
        {
          gender: r.voice&.humanize || "Unknown",
          speakers: r.speaker_count,
          hours: (r.seconds.to_f / 3600).round(2),
          pct: pct(r.seconds.to_f, total)
        }
      end
    end

    def location_stats
      {
        total: Location.count,
        by_region: Location.group(:dialect_region).count,
        with_coordinates: Location.with_coordinates.count,
        recordings_with_location: VoiceRecording.where.not(location_id: nil).count,
        recordings_without_location: VoiceRecording.where(location_id: nil).count
      }
    end

    def recent_analyses
      VoiceRecording
        .where.not(metadata_analysis: nil)
        .order(updated_at: :desc)
        .limit(8)
        .map do |vr|
          analysis = vr.metadata_analysis
          {
            id: vr.id,
            title: vr.title.presence || "Recording ##{vr.id}",
            dialect: analysis["dialect_region"],
            locations: Array(analysis["locations"]).map { |l| l["name"] }.first(2).join(", "),
            topics: Array(analysis["topics"]).first(3).join(", "),
            analyzed_at: Time.parse(analysis["analyzed_at"]).strftime("%d %b %Y") rescue "—"
          }
        end
    end

    def pct(count, total)
      return 0 if total.to_f.zero?
      (count.to_f / total * 100).round(1)
    end
  end
end
