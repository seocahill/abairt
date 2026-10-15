# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_token :api_token
  has_secure_token :login_token
  # Backs the long-lived "stay signed in" cookie. Regenerating it signs every
  # device out, which is the only revocation a permanent cookie can have.
  has_secure_token :remember_token
  # Handed to a speaker as a t.me link so they can be connected to their chat
  # without us holding a phone number. Cleared when redeemed — see
  # Telegram::InboundMessage.
  has_secure_token :telegram_invite_token

  # validations: false because most users never get a password — speakers are
  # created by hand with only a phone number, and the magic link still works
  # for everyone else. Length is enforced below, only when one is being set.
  has_secure_password validations: false

  belongs_to :location, optional: true

  has_many :dictionary_entries # , foreign_key: :speaker_id
  has_many :spoken_dictionary_entries, foreign_key: :speaker_id, class_name: "DictionaryEntry"
  has_many :voice_recordings, -> { distinct }, through: :dictionary_entries
  has_many :spoken_voice_recordings, -> { distinct }, through: :spoken_dictionary_entries, class_name: "VoiceRecording", source: :voice_recording

  has_many :fts_users, class_name: "FtsUser", foreign_key: "rowid"

  has_many :vocabulary_entries, through: :word_lists, source: :dictionary_entries

  has_many :word_lists

  has_many :questions, foreign_key: :asker_id
  has_many :asked_questions, foreign_key: :speaker_id, class_name: "Question"

  enum :role, {student: 0, speaker: 1, teacher: 2, admin: 3, ai: 4, place: 5, temporary: 6, api_user: 7}
  # A speaker has no email, but the admin form still posts an empty string for
  # it. Stored as nothing rather than "" so "no email" is one value, not two.
  # Not downcased: existing rows were never normalised and rewriting them is a
  # separate question from this one.
  normalizes :email, with: ->(address) { address.to_s.strip.presence }
  # A shared contact card arrives as E.164 with a leading "+"; a speaker's
  # number is stored as digits only.
  normalizes :phone_number, with: ->(number) { number.to_s.gsub(/\D/, "").presence }
  # An empty string from the admin form would otherwise count as an address: it
  # satisfies `IS NOT NULL` in the `answering` scope, so the speaker would be
  # routed questions that could never be delivered — and a second blank one
  # would collide on the unique index.
  normalizes :telegram_chat_id, with: ->(id) { id.to_s.strip.presence }

  enum :voice, {male: 0, female: 1}
  enum :dialect, {tuaisceart_mhaigh_eo: 0, "connacht_\u00F3_thuaidh": 1, acaill: 2, "l\u00E1r_chonnachta": 3, "can\u00FAint\u00ED_eile": 4}
  # ref: https://rm.coe.int/CoERMPublicCommonSearchServices/DisplayDCTMContent?documentId=090000168045bb52
  enum :ability, {A1: 0, A2: 1, B1: 2, B2: 3, C1: 4, C2: 5, native: 6}

  # Speakers are onboarded by phone and never touch a web form, so they have a
  # number instead of an email address.
  # A speaker needs no email: they never see a web page. On Telegram they need
  # no phone number either, because an invite link identifies them instead.
  validates :email, presence: true, unless: -> { phone_number.present? || telegram_speaker? }
  validates :email, uniqueness: {case_sensitive: false}, allow_blank: true
  validates :phone_number, uniqueness: true, allow_nil: true
  validates :password, length: {minimum: 8}, allow_nil: true
  # has_secure_password(validations: false) skips this too, but the setter exists.
  validates :password, confirmation: true, allow_nil: true
  validates :name, presence: true
  validates :role, exclusion: {in: %w[teacher api_user admin]}, if: -> { role_changed? && Current.user&.admin? == false }

  scope :active, -> { where.not(role: :temporary) }
  # Only answering once we hold the chat to send to — otherwise the queue would
  # pick them and have nowhere to put the question. The chat id arrives when
  # they follow their invite link.
  scope :answering, -> { where(answers_questions: true).where.not(telegram_chat_id: nil) }
  scope :with_api_token, -> { where.not(api_token: nil) }
  scope :pending, -> { where(confirmed: false) }
  scope :by_role, ->(role) { where(role: role) if role.present? && roles.key?(role) }
  scope :search, ->(query) {
    return all if query.blank?
    # Use FTS for name search (escape special characters), LIKE for email search
    name_ids = []
    begin
      # Escape special FTS characters and quote the query
      escaped_query = query.gsub(/["'\\]/, "")
      name_ids = FtsUser.where("fts_users MATCH ?", escaped_query).pluck(:rowid) if escaped_query.present?
    rescue ActiveRecord::StatementInvalid
      # If FTS query fails, fall back to LIKE for name
      name_ids = where("LOWER(name) LIKE ?", "%#{query.downcase}%").pluck(:id)
    end
    email_ids = where("LOWER(email) LIKE ?", "%#{query.downcase}%").pluck(:id)
    where(id: (name_ids + email_ids).uniq)
  }

  def telegram_speaker?
    answers_questions?
  end

  # nil once redeemed, and nil if we do not know the bot's username — in which
  # case admin says so rather than printing a link that goes nowhere.
  def telegram_invite_link
    return nil if telegram_invite_token.blank? || bot_username.blank?

    "https://t.me/#{bot_username}?start=#{telegram_invite_token}"
  end

  def bot_username
    Rails.application.credentials.dig(:telegram, :bot_username) || ENV["TELEGRAM_BOT_USERNAME"]
  end

  def all_entries
    dictionary_entries.or(spoken_dictionary_entries)
  end

  def all_recordings
    voice_recordings.or(spoken_voice_recordings.distinct)
  end

  class << self
    def pins
      users = where.not(lat_lang: nil)
      return [] if users.empty?

      user_ids = users.pluck(:id)

      # Get one voice recording per user in a single query
      recording_ids = DictionaryEntry
        .where(user_id: user_ids)
        .where.not(voice_recording_id: nil)
        .group(:user_id)
        .pluck(:user_id, Arel.sql("voice_recording_id"))
        .to_h

      recordings_with_media = VoiceRecording
        .where(id: recording_ids.values.uniq)
        .joins(:media_attachment)
        .includes(media_attachment: :blob)
        .index_by(&:id)

      users.select(:id, :name, :lat_lang, :role).map do |user|
        pin = user.slice(:id, :name, :lat_lang, :role)
        if (vr_id = recording_ids[user.id]) && (vr = recordings_with_media[vr_id])
          pin[:media_url] = vr.media.url
        end
        pin
      end
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

  def edit?
    !student? && confirmed
  end
end
