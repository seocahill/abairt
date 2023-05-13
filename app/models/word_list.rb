class WordList < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  # entries
  has_many :word_list_dictionary_entries, dependent: :destroy
  has_many :dictionary_entries, through: :word_list_dictionary_entries


  has_many :user_lists, dependent: :destroy
  has_many :users, through: :user_lists
end
