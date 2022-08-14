# frozen_string_literal: true

class Rang < ApplicationRecord
  has_many :rang_entries, dependent: :destroy
  has_many :dictionary_entries, through: :rang_entries
  belongs_to :user
  belongs_to :grupa

  before_create :generate_meeting_id
  # after_commit :send_notification

  has_one_attached :media

  validates :grupa_id, presence: true

  scope :has_recording, -> { joins(:media_attachment) }

  def next_time
    return  "aon am" unless time
    return "críochnaithe" unless time > Time.now

    time.strftime("%b %e, %l:%M %p %Z")
  end

  def participants
    ([grupa.muinteoir.email] + grupa.users.pluck(:email)).compact
  end

  def send_notification
    return unless time

    NotificationsMailer.with(rang: self).ceád_rang_eile.deliver
  end

  private

  def generate_meeting_id
    begin
      self.meeting_id = SecureRandom.hex
    end while self.class.exists?(meeting_id: meeting_id)
  end
end
