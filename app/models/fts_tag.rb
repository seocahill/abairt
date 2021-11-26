class FtsTag < ApplicationRecord
  self.primary_key = :rowid
  self.table_name = "fts_tags"
end
