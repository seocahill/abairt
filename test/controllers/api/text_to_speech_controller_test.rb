# frozen_string_literal: true

require "test_helper"

module Api
  class TextToSpeechControllerTest < ActionDispatch::IntegrationTest
    setup do
      ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
      audio = Base64.strict_encode64("RIFFfakewav")
      Net::HTTP.any_instance.stubs(:request).returns(stub(body: {audioContent: audio}.to_json))
    end

    test "returns an audio url for an entry" do
      entry = dictionary_entries(:one)

      post api_text_to_speech_index_path, params: {entry_id: entry.id}, as: :json

      assert_response :success
      assert_match %r{/rails/active_storage/blobs/}, response.parsed_body["audioUrl"]
      assert_equal false, response.parsed_body["cached"]
    end

    test "returns an audio url for an entry that fails validation" do
      duplicate = DictionaryEntry.new(dictionary_entries(:one).attributes.except("id"))
      duplicate.save!(validate: false)

      post api_text_to_speech_index_path, params: {entry_id: duplicate.id}, as: :json

      assert_response :success
      assert_match %r{/rails/active_storage/blobs/}, response.parsed_body["audioUrl"]
    end
  end
end
