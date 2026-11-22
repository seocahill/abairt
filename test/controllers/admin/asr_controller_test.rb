require "test_helper"

module Admin
  class AsrControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update(role: :admin)
      sign_in_as(@admin)
    end

    test "shows an admin the report with no flag set" do
      entry = dictionary_entries(:two)
      set = AsrEvalSet.create!(name: "mayo", version: 1, frozen_at: Time.current)
      set.asr_eval_set_entries.create!(dictionary_entry: entry)
      AsrHypothesis.create!(dictionary_entry: entry, provider: "abair", text: "rud eile")
      AsrEvaluation.new(set, provider: "abair").call

      get admin_asr_index_path
      assert_response :success
      assert_select "h1", "ASR quality"
      assert_match "abair", response.body
    end

    test "shows an empty report when there is no evaluation set" do
      get admin_asr_index_path
      assert_response :success
      assert_select "h1", "ASR quality"
    end

    test "non-admins are redirected" do
      sign_in_as(users(:two))
      get admin_asr_index_path
      assert_redirected_to root_path
    end

    test "signed-out visitors can't see it" do
      delete logout_path
      get admin_asr_index_path
      assert_redirected_to root_path
    end

    private

    def sign_in_as(user)
      user.regenerate_login_token if user.login_token.blank?
      post login_path, params: {token: user.login_token}
    end
  end
end
