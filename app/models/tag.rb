class Tag < ApplicationRecord
  has_many :fts_tags, class_name: "FtsTag", foreign_key: "rowid"
end
