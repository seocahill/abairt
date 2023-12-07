# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token
  after_create :add_default_rang

  has_many :dictionary_entries #, foreign_key: :speaker_id
  has_many :spoken_dictionary_entries, foreign_key: :speaker_id, class_name: "DictionaryEntry"
  has_many :voice_recordings, through: :dictionary_entries
  has_many :spoken_voice_recordings, through: :spoken_dictionary_entries,  class_name: "VoiceRecording"

  has_many :fts_users, class_name: "FtsUser", foreign_key: "rowid"

  has_many :seomras
  has_many :rangs, through: :seomras
  has_many :chats, through: :rangs, source: "dictionary_entries"

  has_many :lectures, class_name: "Rang", foreign_key: "user_id"


  # lists
  has_many :own_lists, class_name: "WordList", foreign_key: "user_id", dependent: :destroy
  has_many :user_lists, dependent: :destroy
  has_many :followed_lists, class_name: "WordList", through: :user_lists

  enum role: [
    :student,
    :speaker,
    :teacher,
    :admin,
    :ai,
    :place
  ]
  enum voice: [:male, :female]
  enum dialect: [:tuaisceart_mhaigh_eo, :connacht_ó_thuaidh, :acaill, :lár_chonnachta, :canúintí_eile]
  # ref: https://rm.coe.int/CoERMPublicCommonSearchServices/DisplayDCTMContent?documentId=090000168045bb52
  enum ability: %i[
    A1
    A2
    B1
    B2
    C1
    C2
    native
  ]

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :role, exclusion: { in: %w(teacher admin) }, if: -> { role_changed? && Current.user&.admin? == false }

  def all_entries
    dictionary_entries.or(spoken_dictionary_entries)
  end

  def all_recordings
    voice_recordings.or(spoken_voice_recordings)
  end

  class << self
    def with_unanswered_ceisteanna
      joins(daltaí: { rangs: :dictionary_entries }).where.not(dictionary_entries: { status: :normal} ).distinct
    end

    def pins
      all.map do |user|
        next unless user.lat_lang.present?

        user.slice(:id, :name, :lat_lang, :role).tap do |c|
          if user.all_recordings.any?
            sample = user.voice_recordings.with_attached_media.order("RANDOM()").limit(1).first
            c[:media_url] = sample.media.url
          end
        end
      end.compact
    end
  end

  def quality
    case ability
    when "A1"
      "low"
    when "A2"
      "low"
    when "B1"
      "low"
    when "B2"
      "fair"
    when "C1"
      "good"
    when "C2"
      "good"
    when "native"
      "excellent"
     end
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
    self.password_reset_token = SecureRandom.urlsafe_base64(32)
    self.password_reset_sent_at = Time.current
  end

  def clear_password_reset_token
    self.password_reset_token = nil
    self.password_reset_sent_at = nil
    save
  end

  def password_reset_token_expired?
    password_reset_sent_at < 5.minutes.ago
  end

  def edit?
    !student? && confirmed
  end

  # private

  def add_default_rang
    caotharnach = User.where(name: "An Caotharnach", role: "ai", email: "ai@abairt.com").first_or_create! do | u|
      u.password = SecureRandom.uuid
    end
    rang = caotharnach.lectures.create(name: "Rang leis an Caotharnach")
    self.rangs << rang
  end

  def generate_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end
end
