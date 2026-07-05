# frozen_string_literal: true

# Create a new draft dictionary entry owned by the acting admin. Starts unconfirmed so it can be
# reviewed/edited before confirmation.
class CreateDictionaryEntryTool < ApplicationTool
  tool_name "create_dictionary_entry"
  description "Create a new (unconfirmed) dictionary entry. Optionally attach it to a speaker and " \
              "a source voice recording."
  input_schema(
    properties: {
      word_or_phrase: {type: "string", description: "The Irish word or phrase"},
      translation: {type: "string", description: "The English translation (optional)"},
      speaker_id: {type: "integer", description: "The user id of the speaker (optional)"},
      voice_recording_id: {type: "integer", description: "Source recording id (optional)"}
    },
    required: ["word_or_phrase"]
  )

  def self.call(word_or_phrase:, server_context:, translation: nil, speaker_id: nil, voice_recording_id: nil)
    guard do
      user = current_user(server_context)
      entry = DictionaryEntry.new(
        word_or_phrase: word_or_phrase,
        translation: translation,
        speaker_id: speaker_id,
        voice_recording_id: voice_recording_id,
        owner: user,
        translator: (translation.present? ? user : nil)
      )
      entry.save!
      ok(Mcp::EntryDetailSerializer.new(entry, params: {host: host(server_context)}).serializable_hash)
    end
  end
end
