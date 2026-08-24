require "test_helper"

class LogNavigationAuthenticationTest < ActionDispatch::IntegrationTest
  test "month and future logs require authentication" do
    get monthly_log_path
    assert_redirected_to new_session_path

    get future_log_path
    assert_redirected_to new_session_path
  end
end
