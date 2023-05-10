# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token

  has_many :dictionary_entries, foreign_key: :speaker_id

  has_many :fts_users, class_name: "FtsUser", foreign_key: "rowid"

  has_many :seomras
  has_many :rangs, through: :seomras

  has_many :lectures, class_name: "Rang", foreign_key: "user_id"

  has_many :conversations
  has_many :voice_recordings, through: :conversations

  enum role: [:student, :speaker, :teacher, :admin]
  enum voice: [:male, :female]
  enum dialect: [:an_muirthead, :dún_chaocháin, :acaill, :tuar_mhic_éadaigh]

  class << self
    def with_unanswered_ceisteanna
      joins(daltaí: { rangs: :dictionary_entries }).where.not(dictionary_entries: { status: :normal} ).distinct
    end
  end

  def address
    return "no address provided" if lat_lang.nil?

    results = Geocoder.search(lat_lang.split(','))
    address = results.first.data.dig("address", "city_district")
  end

  private

  def generate_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end
end
