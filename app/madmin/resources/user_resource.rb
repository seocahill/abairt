class UserResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :email
  attribute :name
  attribute :confirmed
  attribute :about
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :token
  attribute :lat_lang
  attribute :role
  attribute :voice
  attribute :dialect
  attribute :password_reset_token
  attribute :password_reset_sent_at
  attribute :password, index: false, show: false
  attribute :password_confirmation, index: false, show: false

  # Associations
  attribute :dictionary_entries
  attribute :voice_recordings
  attribute :rangs
  attribute :chats
  attribute :lectures
  attribute :own_lists

  # Uncomment this to customize the display name of records in the admin area.
  # def self.display_name(record)
  #   record.name
  # end

  # Uncomment this to customize the default sort column and direction.
  # def self.default_sort_column
  #   "created_at"
  # end
  #
  # def self.default_sort_direction
  #   "desc"
  # end
end
