# frozen_string_literal: true

class Rang < ApplicationRecord
  has_many :rang_entries, dependent: :destroy
  has_many :dictionary_entries, through: :rang_entries
  belongs_to :user

  has_one_attached :media
end
