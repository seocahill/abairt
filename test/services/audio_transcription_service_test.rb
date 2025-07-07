require 'test_helper'

class AudioTranscriptionServiceTest < ActiveSupport::TestCase
  def setup
    @entry = dictionary_entries(:one)
    @file_path = '/tmp/test_audio.wav'
    @service = AudioTranscriptionService.new(@entry, @file_path)
  end

  test "process assigns translation when translation service returns text" do
    # Mock the transcription to return some text
    @service.stubs(:transcribe_audio).returns('Dia duit')
    
    # Mock the translation service to return translation
    mock_translation_service = mock('TranslationService')
    mock_translation_service.stubs(:translate).returns('Hello')
    TranslationService.stubs(:new).returns(mock_translation_service)
    
    @entry.word_or_phrase = nil
    @entry.translation = nil
    
    @service.process
    
    assert_equal 'Dia duit', @entry.word_or_phrase
    assert_equal 'Hello', @entry.translation
  end

  test "process does not assign translation when translation service returns nil" do
    # Mock the transcription to return some text
    @service.stubs(:transcribe_audio).returns('Dia duit')
    
    # Mock the translation service to return nil
    mock_translation_service = mock('TranslationService')
    mock_translation_service.stubs(:translate).returns(nil)
    TranslationService.stubs(:new).returns(mock_translation_service)
    
    @entry.word_or_phrase = nil
    @entry.translation = nil
    
    @service.process
    
    assert_equal 'Dia duit', @entry.word_or_phrase
    assert_nil @entry.translation
  end

  test "process skips translation if translation is already present" do
    @entry.translation = 'Already translated'
    
    # Mock the transcription to return some text
    @service.stubs(:transcribe_audio).returns('Dia duit')
    
    # TranslationService should not be called
    TranslationService.expects(:new).never
    
    @service.process
    
    assert_equal 'Already translated', @entry.translation
  end
end 