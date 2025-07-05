# frozen_string_literal: true

class StatusController < ApplicationController
  def index
    authorize :status
    
    @tts_status = ServiceStatus.current_status('tts')
    @asr_status = ServiceStatus.current_status('asr')
    
    @tts_history = ServiceStatus.for_service('tts').recent.limit(24)
    @asr_history = ServiceStatus.for_service('asr').recent.limit(24)
    
    @tts_uptime = calculate_uptime('tts')
    @asr_uptime = calculate_uptime('asr')
  end

  private

  def calculate_uptime(service_name)
    recent_statuses = ServiceStatus.for_service(service_name).recent
    return 0 if recent_statuses.empty?
    
    up_count = recent_statuses.where(status: 'up').count
    total_count = recent_statuses.count
    
    (up_count.to_f / total_count * 100).round(1)
  end
end 