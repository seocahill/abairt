# frozen_string_literal: true

class Rang < ApplicationRecord
  has_many :rang_entries, dependent: :destroy
  has_many :dictionary_entries, through: :rang_entries
  belongs_to :user

  before_create :generate_meeting_id
  after_commit :send_notification

  has_one_attached :media

  def next_time
    return  "aon am" unless time
    return "críochnaithe" unless time > Time.now

    time.strftime("%b %e, %l:%M %p %Z")
  end

  def participants
    ([user.email] + user.daltaí.pluck(:email) + [user.máistir&.email]).compact
  end

  private

  def generate_meeting_id
    begin
      self.meeting_id = SecureRandom.hex
    end while self.class.exists?(meeting_id: meeting_id)
  end

  def send_notification
    return unless time
    return time > Time.now

     NotificationsMailer.with(rang: self).ceád_rang_eile
  end
end
