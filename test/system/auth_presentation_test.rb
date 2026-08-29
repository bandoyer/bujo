require "application_system_test_case"

# Verifies the approved magic-first authentication sheet at its phone profiles.
class AuthPresentationTest < ApplicationSystemTestCase
  PROFILES = {
    "390-light-rock-salt" => { width: 390, theme: "light", hand: "rock-salt" },
    "320-dark-architects" => { width: 320, theme: "dark", hand: "architects-daughter" },
    "390-system-marker" => { width: 390, theme: nil, hand: nil }
  }.freeze

  test "magic-email and password fallback states match the accepted controls and copy" do
    PROFILES.each do |name, profile|
      visit new_session_path
      apply_profile(name, profile)

      assert_title_first "Open your journal"
      assert_text "Pick up where you left off."
      email = find_field("Email")
      assert_equal "email_address", email[:name]
      assert_equal "email", email[:autocomplete]
      assert_equal "none", email[:autocapitalize]
      assert_equal "false", email[:spellcheck]
      assert_equal "you@example.com", email[:placeholder]
      assert email[:required]
      assert email[:autofocus]
      assert_button "Email me a sign-in link"
      assert_text "A one-time link, with nothing to remember."
      assert_link "Use password instead", href: new_session_path(method: "password")
      assert_excluded_product_controls
      assert_accessible_phone_geometry

      click_link "Use password instead"
      apply_profile(name, profile)
      assert_title_first "Open your journal"
      assert_text "Use your current password."
      assert_equal "username", find_field("Email")[:autocomplete]
      password = find_field("Password")
      assert_equal "current-password", password[:autocomplete]
      assert_equal "72", password[:maxlength]
      assert_button "Sign in"
      assert_link "Forgot password?", href: new_password_path
      assert_link "Use email instead", href: new_session_path
      assert_excluded_product_controls
      assert_accessible_phone_geometry
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "invalid password and password-reset pages use the same title-first sheet" do
    visit new_session_path(method: "password")
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "wrong"
    click_button "Sign in"

    assert_title_first "Open your journal"
    assert_no_selector "#flash_messages"
    assert_selector ".auth-alert[role='alert']", count: 1, text: "Try another email address or password."

    visit new_password_path
    assert_title_first "Forgot your password?"
    assert_selector "main.auth-sheet"
    assert_field "Email"
    assert_button "Email reset instructions"

    visit edit_password_path(users(:one).password_reset_token)
    assert_title_first "Update your password"
    assert_selector "main.auth-sheet"
    assert_field "New password"
    assert_field "Repeat new password"
  end

  test "known and unknown requests reach the same dedicated acknowledgement" do
    [ users(:one).email_address, "unknown-auth-user@example.com" ].each do |address|
      visit new_session_path
      fill_in "Email", with: address
      click_button "Email me a sign-in link"

      assert_current_path sent_sign_in_link_path
      assert_title_first "Check your email"
      assert_text "If that email belongs to an account, a sign-in link is on its way."
      assert_text "It may take a minute to arrive."
      assert_link "Back to sign in", href: new_session_path
      assert_no_text address
    end
  end

  private

  def apply_profile(name, profile)
    page.current_window.resize_to(profile.fetch(:width), 844)
    page.execute_script(<<~JAVASCRIPT, name, profile[:theme], profile[:hand])
      document.documentElement.dataset.authProfile = arguments[0]
      if (arguments[1]) document.documentElement.dataset.theme = arguments[1]
      else delete document.documentElement.dataset.theme
      if (arguments[2]) document.documentElement.dataset.hand = arguments[2]
      else delete document.documentElement.dataset.hand
    JAVASCRIPT
  end

  def assert_title_first(title)
    assert_selector "main.auth-sheet > h1:first-child", text: title
  end

  def assert_excluded_product_controls
    assert_no_text(/passkey|sign up|theme|lettering/i)
    assert_no_selector ".tab-bar"
    assert_no_selector "[data-controller~='preference']"
  end

  def assert_accessible_phone_geometry
    assert page.evaluate_script(<<~JAVASCRIPT), "an auth control is shorter than 44px"
      [...document.querySelectorAll("main :is(input, button, a.auth-secondary)")]
        .every((element) => element.getBoundingClientRect().height >= 44)
    JAVASCRIPT
    assert page.evaluate_script(<<~JAVASCRIPT), "authentication sheet overflows horizontally"
      document.documentElement.scrollWidth <= document.documentElement.clientWidth
    JAVASCRIPT
    assert page.evaluate_script(<<~JAVASCRIPT), "the autofocus field did not receive focus"
      document.activeElement === document.querySelector("[autofocus]")
    JAVASCRIPT
  end
end
