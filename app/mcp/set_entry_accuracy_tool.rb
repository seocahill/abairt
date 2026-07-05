# frozen_string_literal: true

# Confirm or deconfirm an entry's accuracy. Confirming marks a translation as trusted corpus data;
# deconfirming unlocks it for editing. Authorized with the entry's confirm?/deconfirm? policy and
# versioned by PaperTrail.
class SetEntryAccuracyTool < ApplicationTool
  tool_name "set_entry_accuracy"
  description "Confirm or deconfirm a dictionary entry. Use 'confirmed' to mark it as trusted, " \
              "'unconfirmed' to unlock it for further editing. Changes are versioned."
  input_schema(
    properties: {
      id: {type: "integer", description: "The dictionary entry id"},
      status: {type: "string", enum: %w[confirmed unconfirmed], description: "Target accuracy status"}
    },
    required: ["id", "status"]
  )

  def self.call(id:, status:, server_context:)
    guard do
      entry = DictionaryEntry.find(id)
      action = (status == "confirmed") ? :confirm? : :deconfirm?
      authorize!(current_user(server_context), entry, action)

      entry.update!(accuracy_status: status)
      ok(Mcp::EntryDetailSerializer.new(entry, params: {host: host(server_context)}).serializable_hash)
    end
  end
end
