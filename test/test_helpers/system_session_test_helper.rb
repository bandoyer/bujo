# Shared browser helpers for exercising the real session form.
module SystemSessionTestHelper
  # Every fixture user is seeded with this password.
  FIXTURE_PASSWORD = "password".freeze

  # Signs in through the same form a person uses, and waits for the landing page.
  def sign_in_through_browser(user)
    submit_sign_in_form(user, password: FIXTURE_PASSWORD)
    assert_current_path root_path
  end

  # Fills and submits the sign-in form without assuming the attempt succeeds.
  def submit_sign_in_form(user, password:)
    visit new_session_path(method: "password")
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button "Sign in"
  end
end
