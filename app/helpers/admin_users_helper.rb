# frozen_string_literal: true

# Names for the kinds of person on the admin users pages (see User::KINDS).
module AdminUsersHelper
  KIND_LABELS = {
    "members" => "Members",
    "speakers" => "Speakers",
    "staff" => "Staff & API",
    "other" => "Other",
    "all" => "All"
  }.freeze

  KIND_DESCRIPTIONS = {
    "members" => "People who signed up to edit, transcribe or translate. New sign-ups wait here for approval.",
    "speakers" => "The people who are recorded and who answer questions. They never sign in.",
    "staff" => "Admins, and accounts that reach the corpus through the API.",
    "other" => "Not people: AI voices, places, and the unnamed speakers diarisation creates.",
    "all" => "Everyone, of every kind."
  }.freeze

  NEW_USER_LABELS = {
    "members" => "New member",
    "speakers" => "New speaker",
    "staff" => "New staff or API user"
  }.freeze

  def admin_user_kind_label(kind)
    KIND_LABELS.fetch(kind.to_s)
  end

  def admin_user_kind_description(kind)
    KIND_DESCRIPTIONS.fetch(kind.to_s)
  end

  # Every role, grouped by kind, so moving someone to another kind is still
  # one change of role.
  def admin_user_role_options(user)
    groups = User::KINDS.map do |kind, roles|
      [admin_user_kind_label(kind), roles.map { |role| [role.humanize, role] }]
    end
    grouped_options_for_select(groups, user.role)
  end
end
