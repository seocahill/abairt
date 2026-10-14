# frozen_string_literal: true

# Base class for every abairt MCP tool.
#
# Tools are thin adapters: they parse validated input, resolve the acting admin user from the
# server context, delegate to the same models/services/operations the rest of the app uses,
# authorize writes with Pundit, and serialize the result with the shared MCP serializers.
#
# Subclasses register themselves in REGISTRY (see `inherited`) so McpController can expose the
# full set without an eager-loading dependency. Each concrete tool must live in app/mcp and
# subclass ApplicationTool.
class ApplicationTool < MCP::Tool
  # Explicit registry, ordered as declared. Populated by `inherited` when each tool file loads.
  REGISTRY = []

  class << self
    def inherited(subclass)
      super
      REGISTRY << subclass unless REGISTRY.include?(subclass)
    end

    # Every registered tool. Eager-loads app/mcp first so REGISTRY is complete even under lazy
    # autoloading in development (in eager-loaded environments this is a no-op).
    def all
      loader = Rails.autoloaders.main
      loader.eager_load_dir(Rails.root.join("app/mcp")) if loader.respond_to?(:eager_load_dir)
      REGISTRY
    end

    # The admin User acting through the MCP session.
    def current_user(server_context)
      server_context.fetch(:user)
    end

    def host(server_context)
      server_context[:host]
    end

    # Pundit authorization for write tools. Raises Pundit::NotAuthorizedError on failure, which
    # `call` implementations rescue via `guard` to return a clean tool error.
    def authorize!(user, record, action)
      policy = Pundit.policy!(user, record)
      raise Pundit::NotAuthorizedError.new(query: action, record: record, policy: policy) unless policy.public_send(action)

      record
    end

    # Wraps a tool body, translating the common domain failures into structured tool errors
    # instead of 500s so the model gets an actionable message.
    def guard
      yield
    rescue ActiveRecord::RecordNotFound => e
      error(e.message.presence || "Record not found.")
    rescue Pundit::NotAuthorizedError
      error("You are not authorized to perform that action.")
    rescue ActiveRecord::RecordInvalid => e
      error("Validation failed: #{e.record.errors.full_messages.join("; ")}")
    end

    # Success response. Serializes to pretty JSON text and mirrors it as structuredContent so
    # both text-only and structured MCP clients get the data.
    def ok(data)
      MCP::Tool::Response.new(
        [{type: "text", text: JSON.pretty_generate(data)}],
        structured_content: data
      )
    end

    # Error response flagged with isError so the client/model can react.
    def error(message)
      MCP::Tool::Response.new([{type: "text", text: message}], error: true)
    end
  end
end
