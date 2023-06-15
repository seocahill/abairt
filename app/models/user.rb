# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token

  has_many :dictionary_entries, foreign_key: :speaker_id

  has_many :fts_users, class_name: "FtsUser", foreign_key: "rowid"

  has_many :seomras
  has_many :rangs, through: :seomras
  has_many :chats, through: :rangs, source: "dictionary_entries"

  has_many :lectures, class_name: "Rang", foreign_key: "user_id"

  has_many :conversations
  has_many :voice_recordings, through: :conversations

  # lists
  has_many :own_lists, class_name: "WordList", foreign_key: "user_id", dependent: :destroy
  has_many :user_lists, dependent: :destroy
  has_many :followed_lists, class_name: "WordList", through: :user_lists

  enum role: [:student, :speaker, :teacher, :admin]
  enum voice: [:male, :female]
  enum dialect: [:tuaisceart_mhaigh_eo, :connacht_ó_thuaidh, :acaill, :lár_chonnachta, :canúintí_eile]

  validates :email, presence: true, uniqueness: { case_sensitive: false }, length: {maximum: 50}


  class << self
    def with_unanswered_ceisteanna
      joins(daltaí: { rangs: :dictionary_entries }).where.not(dictionary_entries: { status: :normal} ).distinct
    end

    def pins
      all.map do |user|
        next unless user.lat_lang.present?

        user.slice(:id, :name, :lat_lang).tap do |c|
          if user.voice_recordings.any?
            sample = user.voice_recordings.with_attached_media.order("RANDOM()").limit(1).first
            c[:media_url] = sample.media.url
          end
        end
      end.compact
    end
  end

  def address
    return "no address provided" if lat_lang.nil?

    results = Geocoder.search(lat_lang.split(','))
    address = results.first.data.dig("address", "city_district")
  end

  def starred
    own_lists.where(starred: true).first_or_create! do |list|
      list.name = "Starred"
      list.description = "My favourite words and phrases."
    end
  end

  def recent_messages
    last_24_hours = Time.now.utc - 24.hours
    chats.where("dictionary_entries.created_at >= ?", last_24_hours.to_s)
  end

  def generate_password_reset_token
    self.password_reset_token = SecureRandom.urlsafe_base64
    self.password_reset_sent_at = Time.current
  end

  def clear_password_reset_token
    self.password_reset_token = nil
    self.password_reset_sent_at = nil
  end

  def password_reset_token_expired?
    password_reset_sent_at < 2.hours.ago
  end

  private

  def generate_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end
end
