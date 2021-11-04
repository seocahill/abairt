# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token

  belongs_to :máistir, class_name: 'User', foreign_key: :master_id, optional: true
  belongs_to :grupa

  has_many :daltaí, class_name: 'User', foreign_key: :master_id
  has_many :muinteoir_grupas, class_name: 'Grupa', foreign_key: :muinteoir_id
  has_many :muinteoir_rangs, through: :muinteoir_grupas, source: :rangs
  has_many :rangs, through: :grupa

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
