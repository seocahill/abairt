# frozen_string_literal: true

require 'test_helper'

class ServiceMonitoringServiceTest < ActiveSupport::TestCase
  setup do
    @service = ServiceMonitoringService.new
  end

  test "monitor_all_services returns hash with tts and asr keys" do
    result = @service.monitor_all_services
    
    assert_includes result.keys, :tts
    assert_includes result.keys, :asr
    assert_includes result[:tts].keys, :status
    assert_includes result[:asr].keys, :status
  end

  test "monitor_tts_service creates service status record" do
    assert_difference 'ServiceStatus.count', 1 do
      @service.monitor_tts_service
    end
    
    status = ServiceStatus.last
    assert_equal 'tts', status.service_name
    assert_includes ['up', 'down'], status.status
  end

  test "monitor_asr_service creates service status record" do
    assert_difference 'ServiceStatus.count', 1 do
      @service.monitor_asr_service
    end
    
    status = ServiceStatus.last
    assert_equal 'asr', status.service_name
    assert_includes ['up', 'down'], status.status
  end

  test "service status records have response time" do
    result = @service.monitor_tts_service
    
    assert result[:response_time].present?
    assert result[:response_time] > 0
    
    status = ServiceStatus.last
    assert status.response_time.present?
    assert status.response_time > 0
  end
end 