# frozen_string_literal: true

class Rang < ApplicationRecord
  has_many :rang_entries, dependent: :destroy
  has_many :dictionary_entries, through: :rang_entries
  accepts_nested_attributes_for :rang_entries

  has_many :seomras, dependent: :destroy
  has_many :users, -> { distinct },through: :seomras
  accepts_nested_attributes_for :seomras

  belongs_to :teacher, class_name: "User", foreign_key: "user_id"

  before_create :generate_meeting_id

  enum context: %i[
    hello weather family job holidays movies books actor football politics news
    home travel
  ]

  accepts_nested_attributes_for :users, reject_if: ->(attributes){ attributes['email'].blank? }, allow_destroy: true

  def next_time
    return  "aon am" unless time
    return "críochnaithe" unless time > Time.now

    time.strftime("%b %e, %l:%M %p %Z")
  end

  private

  def generate_meeting_id
    begin
      self.meeting_id = SecureRandom.hex
    end while self.class.exists?(meeting_id: meeting_id)
  end
end
