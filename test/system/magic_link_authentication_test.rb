require "application_system_test_case"

# Exercises scanner-safe staging and explicit one-use redemption in Chrome.
class MagicLinkAuthenticationTest < ApplicationSystemTestCase
  setup { Rails.cache.clear }

  test "fragmentless landing is inert disabled and silent" do
    user = users(:one)

    assert_no_changes -> { [ user.reload.magic_link_version, user.sessions.count ] } do
      visit open_sign_in_link_path
    end

    assert_current_path open_sign_in_link_path
    assert_selector "main.auth-sheet[data-controller='magic-link']"
    assert_button "Open your journal", disabled: true
    assert_no_selector "[role='alert']"
    assert page.evaluate_script("document.querySelector(\"input[name='token']\").value === ''")
  end

  test "fragment is removed and staged locally until the explicit button is pressed" do
    user = users(:one)
    token = user.generate_token_for(:magic_link)

    visit "#{open_sign_in_link_path}##{ERB::Util.url_encode(token)}"

    assert_current_path open_sign_in_link_path
    assert_not_includes page.current_url, "#"
    assert_button "Open your journal", disabled: false
    assert page.evaluate_script("document.querySelector(\"input[name='token']\").value.length > 0")
    assert page.evaluate_script("!document.body.innerText.includes(document.querySelector(\"input[name='token']\").value)")
    assert page.driver.browser.logs.get(:browser).none? { |entry| entry.message.include?(token) },
      "browser console disclosed a staged credential"

    assert_difference -> { user.sessions.count }, 1 do
      click_button "Open your journal"
      assert_current_path root_path
    end
    assert_equal 1, user.reload.magic_link_version
  end

  test "Turbo snapshot and back navigation retain no staged token" do
    token = users(:one).generate_token_for(:magic_link)
    visit "#{open_sign_in_link_path}##{ERB::Util.url_encode(token)}"
    assert_button "Open your journal", disabled: false

    click_link "Back to sign in"
    assert_current_path new_session_path
    page.go_back

    assert_current_path open_sign_in_link_path
    assert_button "Open your journal", disabled: true
    assert page.evaluate_script("document.querySelector(\"input[name='token']\").value === ''")
  end

  test "blank redemption and reuse converge on the same recovery alert" do
    user = users(:one)
    issued_at = 16.minutes.ago
    expired_token = travel_to(issued_at) { user.generate_token_for(:magic_link) }
    visit "#{open_sign_in_link_path}##{ERB::Util.url_encode(expired_token)}"
    click_button "Open your journal"
    assert_current_path new_session_path
    assert_selector ".auth-alert[role='alert']", text: "That sign-in link is invalid or has expired."

    visit open_sign_in_link_path
    page.execute_script("document.querySelector(\"button[type='submit']\").disabled = false")
    click_button "Open your journal"
    assert_current_path new_session_path
    assert_selector ".auth-alert[role='alert']", text: "That sign-in link is invalid or has expired."

    token = user.generate_token_for(:magic_link)
    assert_equal user, User.consume_magic_link(token)
    visit "#{open_sign_in_link_path}##{ERB::Util.url_encode(token)}"
    click_button "Open your journal"

    assert_current_path new_session_path
    assert_selector ".auth-alert[role='alert']", text: "That sign-in link is invalid or has expired."
  end
end
