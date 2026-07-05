# frozen_string_literal: true

# Set or replace an entry's English translation - either a translation supplied by the assistant,
# or one generated on the fly via TranslationService. The change is authorized with the same
# Pundit policy the UI uses and versioned by PaperTrail, so it is fully reversible.
#
# Confirmed entries are locked by the model (cannot_edit_when_confirmed); deconfirm first.
class SaveTranslationTool < ApplicationTool
  tool_name "save_translation"
  description "Set or replace the English translation of an entry. Provide `translation`, or set " \
              "`generate: true` to produce one with the translation model. Confirmed entries are " \
              "locked - deconfirm them first. Changes are versioned and reversible."
  input_schema(
    properties: {
      id: {type: "integer", description: "The dictionary entry id"},
      translation: {type: "string", description: "The English translation to save"},
      generate: {type: "boolean", description: "Generate the translation with the model instead of supplying one"}
    },
    required: ["id"]
  )

  def self.call(id:, server_context:, translation: nil, generate: false)
    guard do
      entry = DictionaryEntry.find(id)
      authorize!(current_user(server_context), entry, :update?)

      text = translation.presence
      text ||= TranslationService.new(entry).translate if generate

      return error("Provide a `translation` or set `generate: true`.") if text.blank?

      entry.update!(translation: text, translator: current_user(server_context))
      ok(Mcp::EntryDetailSerializer.new(entry, params: {host: host(server_context)}).serializable_hash)
    end
  end
end
