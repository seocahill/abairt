require 'test_helper'

class TranslationServiceTest < ActiveSupport::TestCase
  def setup
    @entry = dictionary_entries(:one)
    @service = TranslationService.new(@entry)
  end

  test "translate returns translation text" do
    # Mock the OpenAI client response
    mock_response = mock('Response')
    mock_response.stubs(:dig).with('choices', 0, 'message', 'content').returns('Hello')
    
    mock_client = mock('OpenAI::Client')
    mock_client.stubs(:chat).returns(mock_response)
    
    OpenAI::Client.stubs(:new).returns(mock_client)
    
    result = @service.translate
    assert_equal 'Hello', result
  end

  test "translate returns nil on error" do
    OpenAI::Client.stubs(:new).raises(StandardError.new('API Error'))
    
    result = @service.translate
    assert_nil result
  end

  test "translate returns nil when response is empty" do
    mock_response = mock('Response')
    mock_response.stubs(:dig).with('choices', 0, 'message', 'content').returns(nil)
    
    mock_client = mock('OpenAI::Client')
    mock_client.stubs(:chat).returns(mock_response)
    
    OpenAI::Client.stubs(:new).returns(mock_client)
    
    result = @service.translate
    assert_nil result
  end
end 