require "application_system_test_case"

# Exercises the existing authentication flow through the real-browser lane.
class SessionsTest < ApplicationSystemTestCase
  test "signing in through the browser" do
    user = users(:one)

    visit root_path
    assert_selector "input[type=email][name=email_address]"
    assert_selector "input[type=password][name=password]"
    assert_button "Sign in"

    sign_in_as(user, password: "wrong")
    assert_current_path new_session_path
    assert_text "Try another email address or password."

    assert_difference -> { user.sessions.count }, 1 do
      sign_in_as(user, password: "password")
      assert_no_text "Try another email address or password."
    end
  end

  private

  def sign_in_as(user, password:)
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button "Sign in"
  end
end
