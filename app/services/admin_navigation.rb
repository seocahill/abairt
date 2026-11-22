# frozen_string_literal: true

# The admin pages, grouped, for the admin sidebar, the phone menu and the
# /admin overview. Admin pages never sit behind a Flipper flag, so every
# admin sees every page.
class AdminNavigation
  Item = Data.define(:title, :description, :path, :turbo)
  Section = Data.define(:title, :items)

  def sections
    definitions.map { |title, items| Section.new(title, items) }
  end

  private

  def definitions
    routes = Rails.application.routes.url_helpers
    {
      "People" => [
        item("Users", "Approve sign-ups, edit people and roles.", routes.admin_users_path),
        item("Email users", "Write to and email users.", routes.admin_emails_path),
        item("Locations", "Check and geocode where speakers are from.", routes.admin_locations_path)
      ],
      "Content" => [
        item("Questions", "The question backlog and who is holding what.", routes.admin_questions_path)
      ],
      "Imports" => [
        item("Media imports", "Queue and retry audio and video imports.", routes.admin_media_imports_path)
      ],
      "Data and ASR" => [
        item("Data dashboard", "Corpus, quality and training-readiness numbers.", routes.admin_data_dashboard_path),
        item("ASR quality", "Word and character error rates on the evaluation set.", routes.admin_asr_index_path),
        item("Training progress", "Checked hours per speaker against targets.", routes.admin_training_progress_index_path),
        item("Island context playground", "Try the island context used to help transcription.", routes.admin_island_context_playground_path)
      ],
      "System" => [
        item("Feature flags", "Switch features on and off (Flipper).", "/flipper", turbo: false),
        item("Jobs", "Background jobs and failures (Mission Control).", "/jobs", turbo: false),
        item("API tokens", "Your personal API tokens.", routes.admin_api_index_path)
      ]
    }
  end

  # turbo: false for the mounted engines (Flipper, Mission Control), which are
  # separate apps that Turbo Drive can't swap in.
  def item(title, description, path, turbo: true)
    Item.new(title, description, path, turbo)
  end
end
