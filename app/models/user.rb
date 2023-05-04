# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token

  has_many :seomras
  has_many :rangs, through: :seomras

  has_many :conversations
  has_many :voice_recordings, through: :conversations


  class << self
    def with_unanswered_ceisteanna
      joins(daltaí: { rangs: :dictionary_entries }).where.not(dictionary_entries: { status: :normal} ).distinct
    end
  end

  private

  def generate_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end
end
