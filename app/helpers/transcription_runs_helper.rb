# frozen_string_literal: true

module TranscriptionRunsHelper
  # A word-level comparison of an entry's current Irish and a re-transcription's
  # new text: the current text with the words that go marked, and the new text
  # with the words that come in marked. Returns [current_html, new_html].
  def word_diff(current, fresh)
    before = []
    after = []
    Diff::LCS.sdiff(current.to_s.split, fresh.to_s.split).each do |change|
      changed = !change.unchanged?
      before << word_marked(change.old_element, :del, changed:) if change.old_element
      after << word_marked(change.new_element, :ins, changed:) if change.new_element
    end
    [safe_join(before, " "), safe_join(after, " ")]
  end

  # "2 lines differ, 1 new" for a run's pending candidates.
  def pending_candidates_summary(run)
    differs = run.pending_counts.fetch("differs", 0)
    "#{pluralize(differs, "line")} #{(differs == 1) ? "differs" : "differ"}, #{run.pending_counts.fetch("new_segment", 0)} new"
  end

  # The recording's audio, which the candidate's play button clips to its time.
  def transcription_run_audio_url(recording)
    return unless recording.media.attached?

    url_for(recording.audio_track.attached? ? recording.audio_track : recording.media)
  end

  private

  def word_marked(word, tag_name, changed:)
    return word unless changed

    content_tag(tag_name, word, class: (tag_name == :del) ? "bg-red-100 text-red-800 rounded px-0.5" : "bg-green-100 text-green-800 rounded px-0.5 no-underline")
  end
end
