# frozen_string_literal: true

# The admin pages, grouped, for the admin menu and the /admin overview.
# Pages behind a Flipper flag are only listed when the flag is on for the
# given user, so no link leads to a 404.
class AdminNavigation
  Item = Data.define(:title, :description, :path, :flag)
  Section = Data.define(:title, :items)

  def initialize(user)
    @user = user
  end

  def sections
    definitions.filter_map do |title, items|
      visible = items.select { |item| item.flag.nil? || Flipper.enabled?(item.flag, @user) }
      Section.new(title, visible) if visible.any?
    end
  end

  private

  def definitions
    routes = Rails.application.routes.url_helpers
    {
      "People" => [
        item("Users", "Approve sign-ups, edit people and roles.", routes.admin_users_path),
        item("Speakers", "Browse the speakers whose Irish is recorded.", routes.users_path),
        item("Email users", "Write to and email users.", routes.admin_emails_path),
        item("Locations", "Check and geocode where speakers are from.", routes.admin_locations_path)
      ],
      "Content" => [
        item("Tags", "The tags used on dictionary entries.", routes.tags_path),
        item("Questions", "The question backlog and who is holding what.", routes.admin_questions_path)
      ],
      "Imports" => [
        item("Media imports", "Queue and retry audio and video imports.", routes.admin_media_imports_path)
      ],
      "Data and ASR" => [
        item("Data dashboard", "Corpus, quality and training-readiness numbers.", routes.admin_data_dashboard_path),
        item("ASR quality", "Word and character error rates on the evaluation set.", routes.admin_asr_index_path, flag: :f75_asr_eval),
        item("Training progress", "Checked hours per speaker against targets.", routes.admin_training_progress_index_path, flag: :f142_training_progress),
        item("Island context playground", "Try the island context used to help transcription.", routes.admin_island_context_playground_path)
      ],
      "System" => [
        item("Feature flags", "Switch features on and off (Flipper).", "/flipper"),
        item("Jobs", "Background jobs and failures (Mission Control).", "/jobs"),
        item("API tokens", "Your personal API tokens.", routes.admin_api_index_path)
      ]
    }
  end

  def item(title, description, path, flag: nil)
    Item.new(title, description, path, flag)
  end
end
