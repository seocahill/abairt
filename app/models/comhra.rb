class Comhra < ApplicationRecord
  # has_many :rang_entries, dependent: :destroy
  # has_many :dictionary_entries, through: :rang_entries
  belongs_to :user
  belongs_to :grupa

  has_many :dictionary_entries

  has_one_attached :media
end
