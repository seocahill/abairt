class VoiceRecordingResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :title
  attribute :description
  attribute :created_at, form: false
  attribute :updated_at, form: false
  # attribute :peaks
  attribute :tag_list, index: false
  attribute :media, index: false

  # Associations
  attribute :dictionary_entries
  attribute :users
  attribute :owner
  attribute :taggings

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
