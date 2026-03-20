class WordList < ApplicationRecord
  belongs_to :user

  # entries
  has_many :word_list_dictionary_entries, dependent: :destroy
  has_many :dictionary_entries, through: :word_list_dictionary_entries

  validates :name, presence: true, uniqueness: { scope: :user }

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << %w[front back audio]

      dictionary_entries.find_each do |entry|
        csv << [entry.word_or_phrase, entry.translation, entry.media.url]
      end
    end
  end
end
