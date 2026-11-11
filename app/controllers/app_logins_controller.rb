# frozen_string_literal: true

# Where the sign-in link emailed by the Android app lands when the app did not
# open it: on a computer, or a phone without the app. It does not use the token.
class AppLoginsController < ApplicationController
  skip_after_action :verify_authorized
  layout "centered_layout"

  def show
  end
end
