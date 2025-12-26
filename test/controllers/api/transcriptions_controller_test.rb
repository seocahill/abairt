# frozen_string_literal: true

require 'test_helper'

module Api
  class TranscriptionsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @user = users(:one)
      @user.regenerate_api_token
      @user.save!
      @confirmed_entry = dictionary_entries(:two)
      @unconfirmed_entry = dictionary_entries(:one)
      
      # Attach media to confirmed entry for API tests
      unless @confirmed_entry.media.attached?
        @confirmed_entry.media.attach(
          io: StringIO.new("fake audio data"),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )
      end
    end

    test "should require authentication" do
      get api_transcriptions_path
      assert_response :unauthorized
    end

    test "should return confirmed entries with valid token" do
      get api_transcriptions_path, headers: { 'Authorization' => "Bearer #{@user.api_token}" }
      assert_response :success
      
      json = JSON.parse(response.body)
      assert json['entries'].is_a?(Array)
      entry_ids = json['entries'].map { |e| e['id'] }
      assert_includes entry_ids, @confirmed_entry.id
      refute_includes entry_ids, @unconfirmed_entry.id
    end

    test "should filter by updated_since" do
      old_time = 1.year.ago.iso8601
      get api_transcriptions_path, 
          params: { updated_since: old_time },
          headers: { 'Authorization' => "Bearer #{@user.api_token}" }
      assert_response :success
      
      json = JSON.parse(response.body)
      assert json['entries'].is_a?(Array)
    end

    test "should return single confirmed entry" do
      get api_transcription_path(@confirmed_entry), 
          headers: { 'Authorization' => "Bearer #{@user.api_token}" }
      assert_response :success
      
      json = JSON.parse(response.body)
      assert_equal @confirmed_entry.id, json['id']
      assert json.key?('audio_url')
      assert_not_nil json['audio_url']
    end

    test "should return 404 for unconfirmed entry" do
      get api_transcription_path(@unconfirmed_entry), 
          headers: { 'Authorization' => "Bearer #{@user.api_token}" }
      assert_response :not_found
    end
  end
end

