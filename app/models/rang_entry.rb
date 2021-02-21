class RangEntry < ApplicationRecord
  belongs_to :rang
  belongs_to :dictionary_entry
end
