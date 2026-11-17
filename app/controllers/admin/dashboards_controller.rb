# frozen_string_literal: true

module Admin
  # The admin home: every admin page, grouped, with a line on what it is for.
  class DashboardsController < ApplicationController
    before_action :ensure_admin
    skip_after_action :verify_authorized

    def show
      @sections = AdminNavigation.new(current_user).sections
    end
  end
end
