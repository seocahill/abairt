module VoiceRecordingsHelper

  def speakers_identified_label(recording)
    total = recording.users.size
    identified = recording.users.reject(&:temporary?).size
    "#{identified}/#{total} speakers identified"
  end

  def transcriptions_confirmed_label(recording)
    total = recording.dictionary_entries.count
    confirmed = recording.dictionary_entries.confirmed_accuracy.count
    "#{confirmed}/#{total} transcriptions confirmed"
  end

  def pill_color(entry)
    case entry.quality
    when "low"
      "bg-gray-100 text-gray-800 text-xs font-medium me-2 px-2.5 py-0.5 rounded-full dark:bg-gray-700 dark:text-gray-300"
    when "fair"
      "bg-indigo-100 text-indigo-800 text-xs font-medium me-2 px-2.5 py-0.5 rounded dark:bg-gray-700 dark:text-indigo-400 border border-indigo-400"
    when "good"
      "bg-yellow-100 text-yellow-800 text-xs font-medium me-2 px-2.5 py-0.5 rounded dark:bg-gray-700 dark:text-yellow-300 border border-yellow-300"
    when "excellent"
      "bg-green-100 text-green-800 text-xs font-medium me-2 px-2.5 py-0.5 rounded dark:bg-gray-700 dark:text-green-400 border border-green-400"
    end
  end
end
