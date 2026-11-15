# frozen_string_literal: true

class RefreshAndroidReleaseJob < ApplicationJob
  queue_as :default

  def perform
    AndroidRelease.refresh
  end
end
