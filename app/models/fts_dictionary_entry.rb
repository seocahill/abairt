class FtsDictionaryEntry < ApplicationRecord
  self.primary_key = :rowid
  self.table_name = "fts_dictionary_entries"
end
