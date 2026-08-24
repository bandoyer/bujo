# Shared browser helpers for exercising the real session form.
module SystemSessionTestHelper
  # Signs in through the same form a person uses.
  def sign_in_through_browser(user, password: "password")
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button "Sign in"
    assert_current_path root_path if password == "password"
  end
end
