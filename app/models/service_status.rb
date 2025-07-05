# frozen_string_literal: true

class ServiceStatus < ApplicationRecord
  validates :service_name, presence: true, inclusion: { in: %w[tts asr pyannote] }
  validates :status, presence: true, inclusion: { in: %w[up down] }
  validates :response_time, numericality: { greater_than: 0 }, allow_nil: true

  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  scope :for_service, ->(service) { where(service_name: service) }
  scope :latest, -> { order(created_at: :desc) }

  def self.current_status(service_name)
    for_service(service_name).latest.first
  end

  def self.is_up?(service_name)
    status = current_status(service_name)
    status&.status == 'up'
  end

  def up?
    status == 'up'
  end

  def down?
    status == 'down'
  end
end 