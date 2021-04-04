# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_create :generate_token

  has_many :rangs

  has_many :daltaí, class_name: 'User', foreign_key: :master_id
  belongs_to :máistir, class_name: 'User', foreign_key: :master_id, optional: true

  private

  def generate_token
    begin
      self.token = SecureRandom.hex
    end while self.class.exists?(token: token)
  end
end
