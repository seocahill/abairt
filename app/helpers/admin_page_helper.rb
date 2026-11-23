# frozen_string_literal: true

# The shared pieces of an admin page, so every admin page looks like one set:
# the page header, the filter tabs and the buttons. The table style is the
# .admin-table utility in app/assets/tailwind/application.css.
module AdminPageHelper
  FILTER_CLASS = "inline-flex items-center min-h-9 px-3 rounded-sm text-sm"
  FILTER_CURRENT_CLASS = "bg-blue-600 text-white"
  FILTER_OTHER_CLASS = "bg-gray-200 text-gray-700 hover:bg-gray-300"

  BUTTON_CLASS = "inline-flex items-center justify-center min-h-9 px-4 rounded-sm text-sm font-medium whitespace-nowrap"
  BUTTON_COLORS = {
    primary: "bg-blue-600 text-white hover:bg-blue-700",
    secondary: "bg-gray-200 text-gray-700 hover:bg-gray-300",
    positive: "bg-green-600 text-white hover:bg-green-700",
    danger: "bg-red-600 text-white hover:bg-red-700"
  }.freeze

  # The top of an admin page: an optional link back to the page above it, the
  # title, an optional one-line subtitle, and the page's actions (the block)
  # on the right, or under the title on a phone.
  #   back: ["Users", admin_users_path]
  def admin_page_header(title, subtitle: nil, back: nil, &actions)
    render "admin/page_header", title:, subtitle:, back:, actions: (capture(&actions) if actions)
  end

  # One filter or view tab; the current one is filled in blue.
  def admin_filter_link(label, path, current:)
    link_to label, path,
      class: [FILTER_CLASS, current ? FILTER_CURRENT_CLASS : FILTER_OTHER_CLASS],
      aria: {current: (current ? "true" : nil)}
  end

  # Classes for a link_to, button_to or submit styled as an admin button.
  def admin_button_class(kind = :primary)
    [BUTTON_CLASS, BUTTON_COLORS.fetch(kind)].join(" ")
  end
end
