require "test_helper"

class ReifiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
    Current.stubs(:user).returns(@user)
    @entry = dictionary_entries(:one)
    @entry.destroy
    @version = @entry.versions.last
  end

  test "should reify the version and redirect to items page with success notice" do
    post reify_url, params: { version_id: @version.id }

    assert_redirected_to @version.item
    assert_equal "Successfully reified", flash[:notice]
  end

  test "should redirect back with an alert when unable to reify the version" do
    PaperTrail::Version.any_instance.stubs(:reify).returns(nil)

    post reify_url, params: { version_id: @version.id }

    assert_redirected_to root_path
    assert_equal "Caithfidh tú a bheith sínithe isteach!", flash[:alert]
  end
end
