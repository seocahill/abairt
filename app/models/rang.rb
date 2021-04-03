# frozen_string_literal: true

class Rang < ApplicationRecord
  has_many :rang_entries, dependent: :destroy
  has_many :dictionary_entries, through: :rang_entries
  belongs_to :user

  before_create :generate_meeting_id

  has_one_attached :media

  private

  def generate_meeting_id
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(meeting_id: meeting_id)
  end
end
