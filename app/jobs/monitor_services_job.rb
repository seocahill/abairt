# frozen_string_literal: true

class MonitorServicesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting service monitoring..."
    
    service = ServiceMonitoringService.new
    results = service.monitor_all_services
    
    results.each do |service_name, result|
      Rails.logger.info "#{service_name.upcase} service: #{result[:status]} (#{result[:response_time]&.round(2)}ms)"
      if result[:error]
        Rails.logger.error "#{service_name.upcase} error: #{result[:error]}"
      end
    end
    
    Rails.logger.info "Service monitoring completed"
  rescue => e
    Rails.logger.error "Service monitoring failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end 