require "application_system_test_case"
require "digest"

# Preserves the intentionally raw generator-era authentication presentation.
# The T0 stylesheet is replayed against each live DOM so native control layout,
# wrapping, and inherited hand treatment are compared on the same browser run.
class AuthPresentationTest < ApplicationSystemTestCase
  T0_STYLESHEET_PATH = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  T0_STYLESHEET_BYTES = 23_218
  T0_STYLESHEET_SHA256 = "df75385665a9f4f48af1f66156953e712493c2e85575de861ffc09963bfa5ceb"
  PROFILES = {
    "390-light-rock-salt" => { width: 390, theme: "light", hand: "rock-salt" },
    "320-dark-architects" => { width: 320, theme: "dark", hand: "architects-daughter" },
    "390-system-marker" => { width: 390, theme: nil, hand: nil }
  }.freeze
  BOX_PROPERTIES = %w[x y width height].freeze
  STYLE_PROPERTIES = %w[color display fontFamily fontSize marginTop marginBottom appearance].freeze

  test "sign in normal and refusal states retain raw T0 anatomy and treatment in every profile" do
    assert_t0_fixture

    PROFILES.each_key do |profile|
      visit new_session_path
      apply_profile(profile)
      wait_for_render
      assert_sign_in_contract
      assert_t0_treatment(profile, %w[email password submit forgot])

      fill_in "Enter your email address", with: users(:one).email_address
      fill_in "Enter your password", with: "wrong"
      click_button "Sign in"
      apply_profile(profile)
      wait_for_render

      assert_selector ".auth-flash.auth-flash--alert", text: "Try another email address or password."
      assert_equal "rgb(255, 0, 0)", computed_style(".auth-flash--alert", "color")
      assert_t0_treatment(profile, %w[alert email password submit forgot])
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "password request and auth notice retain their T0 controls colors and disclosure" do
    assert_t0_fixture

    PROFILES.each_key do |profile|
      visit new_password_path
      apply_profile(profile)
      wait_for_render

      assert_selector "h1", text: "Forgot your password?"
      email = find_field("Enter your email address")
      assert_equal "email_address", email[:name]
      assert_equal "username", email[:autocomplete]
      assert email[:required]
      assert email[:autofocus]
      assert_button "Email reset instructions"
      assert_no_selector ".page-shell"
      assert_t0_treatment(profile, %w[heading email submit])

      fill_in "Enter your email address", with: "unknown-auth-user@example.com"
      click_button "Email reset instructions"
      apply_profile(profile)
      wait_for_render
      assert_current_path new_session_path
      assert_selector ".auth-flash.auth-flash--notice", text: /reset instructions sent/i
      assert_equal "rgb(0, 128, 0)", computed_style(".auth-flash--notice", "color")
      assert_t0_treatment(profile, %w[notice email password submit forgot])
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def assert_sign_in_contract
    email = find_field("Enter your email address")
    password = find_field("Enter your password")
    assert_equal "email_address", email[:name]
    assert_equal "username", email[:autocomplete]
    assert email[:required]
    assert email[:autofocus]
    assert_equal "password", password[:name]
    assert_equal "current-password", password[:autocomplete]
    assert_equal "72", password[:maxlength]
    assert password[:required]
    assert_button "Sign in"
    assert_link "Forgot password?", href: new_password_path
    assert_no_selector "h1"
    assert_no_selector ".page-shell"
  end

  def assert_t0_fixture
    assert_equal T0_STYLESHEET_BYTES, t0_stylesheet.bytesize
    assert_equal T0_STYLESHEET_SHA256, Digest::SHA256.hexdigest(t0_stylesheet)
  end

  def assert_t0_treatment(profile, keys)
    selectors = {
      "heading" => "h1",
      "alert" => ".auth-flash--alert",
      "notice" => ".auth-flash--notice",
      "email" => "input[type='email']",
      "password" => "input[type='password']",
      "submit" => "input[type='submit']",
      "forgot" => "a"
    }.slice(*keys)
    current = sample(selectors)
    baseline = sample_with_t0_stylesheet(selectors)

    assert_equal profile, current.fetch("profile")
    selectors.each_key do |key|
      BOX_PROPERTIES.each do |property|
        assert_in_delta baseline.dig(key, "rect", property), current.dig(key, "rect", property), 0.75,
          "#{profile} #{key}.#{property} changed from T0"
      end
      STYLE_PROPERTIES.each do |property|
        assert_equal baseline.dig(key, "style", property), current.dig(key, "style", property),
          "#{profile} #{key}.#{property} changed from T0"
      end
    end
    assert_in_delta baseline.dig("viewport", "scrollWidth"), current.dig("viewport", "scrollWidth"), 0.75,
      "#{profile} raw auth overflow changed from T0"
  end

  def sample(selectors)
    profile = page.evaluate_script("document.documentElement.dataset.authProfile")
    page.evaluate_script(<<~JAVASCRIPT, selectors, profile)
      (() => {
        const selectors = arguments[0]
        const result = { profile: arguments[1] }
        for (const [key, selector] of Object.entries(selectors)) {
          const element = document.querySelector(selector)
          const rectangle = element.getBoundingClientRect()
          const style = getComputedStyle(element)
          result[key] = {
            rect: { x: rectangle.x, y: rectangle.y, width: rectangle.width, height: rectangle.height },
            style: Object.fromEntries(
              ["color", "display", "fontFamily", "fontSize", "marginTop", "marginBottom", "appearance"]
                .map((property) => [property, style[property]])
            )
          }
        }
        result.viewport = { scrollWidth: document.documentElement.scrollWidth }
        return result
      })()
    JAVASCRIPT
  end

  def sample_with_t0_stylesheet(selectors)
    page.execute_script(<<~JAVASCRIPT, t0_stylesheet)
      const link = document.querySelector("link[rel='stylesheet'][href*='/assets/tailwind']")
      link.disabled = true
      const style = document.createElement("style")
      style.id = "t0-auth-stylesheet"
      style.textContent = arguments[0] +
        ".auth-flash--alert { color: red } .auth-flash--notice { color: green }"
      document.head.appendChild(style)
    JAVASCRIPT
    wait_for_render
    sample(selectors)
  ensure
    page.execute_script(<<~JAVASCRIPT)
      document.querySelector("#t0-auth-stylesheet")?.remove()
      const link = document.querySelector("link[rel='stylesheet'][href*='/assets/tailwind']")
      if (link) link.disabled = false
    JAVASCRIPT
    wait_for_render
  end

  def apply_profile(profile_name)
    profile = PROFILES.fetch(profile_name)
    page.current_window.resize_to(profile.fetch(:width), 844)
    chrome_height = page.evaluate_script("window.outerHeight - window.innerHeight")
    page.current_window.resize_to(profile.fetch(:width), 844 + chrome_height)
    page.execute_script(<<~JAVASCRIPT, profile_name, profile[:theme], profile[:hand])
      document.documentElement.dataset.authProfile = arguments[0]
      if (arguments[1]) document.documentElement.dataset.theme = arguments[1]
      else delete document.documentElement.dataset.theme
      if (arguments[2]) document.documentElement.dataset.hand = arguments[2]
      else delete document.documentElement.dataset.hand
    JAVASCRIPT
  end

  def wait_for_render
    page.driver.browser.execute_async_script(<<~JAVASCRIPT)
      const done = arguments[arguments.length - 1]
      document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
    JAVASCRIPT
  end

  def computed_style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property)
  end

  def t0_stylesheet
    @t0_stylesheet ||= T0_STYLESHEET_PATH.binread
  end
end
