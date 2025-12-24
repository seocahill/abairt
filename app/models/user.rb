# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_token :api_token
  has_secure_token :login_token

  has_many :dictionary_entries #, foreign_key: :speaker_id
  has_many :spoken_dictionary_entries, foreign_key: :speaker_id, class_name: "DictionaryEntry"
  has_many :voice_recordings, -> { distinct }, through: :dictionary_entries
  has_many :spoken_voice_recordings, -> { distinct }, through: :spoken_dictionary_entries,  class_name: "VoiceRecording", source: :voice_recording

  has_many :fts_users, class_name: "FtsUser", foreign_key: "rowid"

  has_many :vocabulary_entries, through: :word_lists, source: :dictionary_entries

  has_many :word_lists

  enum :role, [
    :student,
    :speaker,
    :teacher,
    :admin,
    :ai,
    :place,
    :temporary,
    :api_user
  ]
  enum :voice, [:male, :female]
  enum :dialect, [:tuaisceart_mhaigh_eo, :connacht_ó_thuaidh, :acaill, :lár_chonnachta, :canúintí_eile]
  # ref: https://rm.coe.int/CoERMPublicCommonSearchServices/DisplayDCTMContent?documentId=090000168045bb52
  enum :ability, %i[
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
  validates :role, exclusion: { in: %w(teacher api_user admin) }, if: -> { role_changed? && Current.user&.admin? == false }

  scope :active, -> { where.not(role: :temporary) }
  scope :with_api_token, -> { where.not(api_token: nil) }
  scope :pending, -> { where(confirmed: false) }
  scope :by_role, ->(role) { where(role: role) if role.present? && roles.key?(role) }
  scope :search, ->(query) {
    return all if query.blank?
    # Use FTS for name search (escape special characters), LIKE for email search
    name_ids = []
    begin
      # Escape special FTS characters and quote the query
      escaped_query = query.gsub(/["'\\]/, '')
      name_ids = FtsUser.where("fts_users MATCH ?", escaped_query).pluck(:rowid) if escaped_query.present?
    rescue ActiveRecord::StatementInvalid
      # If FTS query fails, fall back to LIKE for name
      name_ids = where("LOWER(name) LIKE ?", "%#{query.downcase}%").pluck(:id)
    end
    email_ids = where("LOWER(email) LIKE ?", "%#{query.downcase}%").pluck(:id)
    where(id: (name_ids + email_ids).uniq)
  }

  def all_entries
    dictionary_entries.or(spoken_dictionary_entries)
  end

  def all_recordings
    voice_recordings.or(spoken_voice_recordings.distinct)
  end

  class << self
    def pins
      all.map do |user|
        next unless user.lat_lang.present?

        user.slice(:id, :name, :lat_lang, :role).tap do |c|
          if user.all_recordings.any?
            if sample = user.voice_recordings.with_attached_media.order("RANDOM()").limit(1).first
              c[:media_url] = sample.media.url
            end
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

  def generate_password_reset_token
    # Store raw token directly to avoid Rails 8 automatic signing
    token = SecureRandom.urlsafe_base64(32)
    self.password_reset_sent_at = Time.current
    write_attribute(:password_reset_token, token)
  end
  
  # Override accessor to return raw token for compatibility
  def password_reset_token
    read_attribute(:password_reset_token)
  end

  def clear_password_reset_token
    update_columns(password_reset_token: nil, password_reset_sent_at: nil)
  end

  def password_reset_token_expired?
    return true if password_reset_sent_at.blank?
    password_reset_sent_at < 5.minutes.ago
  end

  def edit?
    !student? && confirmed
  end
end
