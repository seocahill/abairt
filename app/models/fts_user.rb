class FtsUser < ApplicationRecord
  self.primary_key = :rowid
  self.table_name = "fts_users"
end
