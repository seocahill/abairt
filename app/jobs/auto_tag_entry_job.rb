class AutoTagEntryJob < ApplicationJob
  queue_as :default

  def perform(entry)
    return unless entry.translation.present?
    return if entry.tag_list.present?

    entry.auto_tag
  end
end
