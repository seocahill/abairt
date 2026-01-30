# frozen_string_literal: true

# Tracks the state of a voice-driven transcription correction session
# Users interact via voice commands to review and correct transcriptions
class ConversationSession < ApplicationRecord
  belongs_to :user
  belongs_to :voice_recording, optional: true
  belongs_to :current_entry, class_name: "DictionaryEntry", optional: true

  # Session states for the voice workflow
  STATES = %w[
    idle
    searching
    selecting_recording
    playing_segment
    confirming_transcription
    correcting_transcription
    confirming_translation
    correcting_translation
    complete
  ].freeze

  validates :state, inclusion: { in: STATES }

  scope :active, -> { where.not(state: %w[idle complete]) }
  scope :for_user, ->(user) { where(user: user) }

  # State predicates
  STATES.each do |state_name|
    define_method(:"#{state_name}?") { state == state_name }
  end

  # Add a message to conversation history
  def add_message(role:, content:, metadata: {})
    conversation_history << {
      role: role,
      content: content,
      timestamp: Time.current.iso8601,
      **metadata
    }
    save!
  end

  # Get recent conversation for context (last N exchanges)
  def recent_history(limit: 10)
    conversation_history.last(limit)
  end

  # Transition to a new state
  def transition_to!(new_state)
    raise ArgumentError, "Invalid state: #{new_state}" unless STATES.include?(new_state)

    update!(state: new_state)
  end

  # Move to next entry in the voice recording
  def advance_to_next_entry!
    return unless voice_recording

    entries = voice_recording.dictionary_entries.order(:region_start)
    current_index = current_entry ? entries.find_index(current_entry) : -1
    next_entry = entries[current_index + 1]

    if next_entry
      update!(current_entry: next_entry)
      transition_to!("playing_segment")
      next_entry
    else
      transition_to!("complete")
      nil
    end
  end

  # Start working on a specific voice recording
  def start_recording!(recording)
    update!(
      voice_recording: recording,
      current_entry: nil,
      state: "playing_segment"
    )
    advance_to_next_entry!
  end

  # Reset session to idle
  def reset!
    update!(
      voice_recording: nil,
      current_entry: nil,
      state: "idle",
      conversation_history: [],
      context: {}
    )
  end

  # Store temporary context (e.g., pending correction)
  def store_context(key, value)
    context[key.to_s] = value
    save!
  end

  def fetch_context(key)
    context[key.to_s]
  end

  def clear_context(key)
    context.delete(key.to_s)
    save!
  end
end
