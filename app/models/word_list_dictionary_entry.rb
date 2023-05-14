class WordListDictionaryEntry < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :word_list
end
