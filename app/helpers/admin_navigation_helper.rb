# frozen_string_literal: true

module AdminNavigationHelper
  LINK_CLASS = "flex items-center min-h-12 md:min-h-10 px-3 rounded-lg text-sm"
  CURRENT_CLASS = "bg-gray-900 text-white font-medium"
  OTHER_CLASS = "text-gray-300 hover:bg-gray-700 hover:text-white"

  # A link in the admin menu, marked when it is the page being shown or a page
  # under it (a user's edit page marks Users). The overview only marks itself.
  def admin_nav_link(title, path, exact: false, turbo: true)
    current = exact ? request.path == path : admin_nav_current?(path)
    link_to title, path,
      class: [LINK_CLASS, current ? CURRENT_CLASS : OTHER_CLASS],
      aria: {current: (current ? "page" : nil)},
      data: {turbo: (turbo ? nil : false)}
  end

  private

  def admin_nav_current?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end
end
