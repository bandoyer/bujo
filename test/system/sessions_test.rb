require "application_system_test_case"

# Exercises the existing authentication flow through the real-browser lane.
class SessionsTest < ApplicationSystemTestCase
  test "signing in through the browser" do
    user = users(:one)

    visit root_path
    assert_selector "input[type=email][name=email_address]"
    assert_selector "input[type=password][name=password]"
    assert_button "Sign in"

    submit_sign_in_form(user, password: "wrong")
    assert_current_path new_session_path
    assert_text "Try another email address or password."

    assert_difference -> { user.sessions.count }, 1 do
      sign_in_through_browser(user)
      assert_no_text "Try another email address or password."
    end
  end
end
