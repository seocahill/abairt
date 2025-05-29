class DictionaryEntryResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :word_or_phrase
  attribute :translation
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :region_start
  attribute :region_end
  attribute :region_id
  attribute :user_id
  attribute :tag_list, index: false
  attribute :media, index: false
  attribute :quality

  # Associations
  attribute :speaker
  attribute :owner
  attribute :voice_recording
  attribute :tags

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
