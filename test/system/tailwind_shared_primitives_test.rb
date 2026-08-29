require "application_system_test_case"

# Verifies the shared T2 owners through the same headless-Chrome lane used by
# the product acceptance suite. Page-family composition remains covered by its
# existing T3/T4 tests.
class TailwindSharedPrimitivesTest < ApplicationSystemTestCase
  PROFILES = [
    [ 390, "light", "rock-salt" ],
    [ 320, "dark", "architects-daughter" ]
  ].freeze
  HANDS = {
    nil => "Permanent Marker",
    "rock-salt" => "Rock Salt",
    "architects-daughter" => "Architects Daughter",
    "patrick-hand" => "Patrick Hand",
    "gochi-hand" => "Gochi Hand",
    "sans" => "Public Sans"
  }.freeze

  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "default system and explicit themes keep precedence while every hand renders" do
    sign_in

    page.execute_script("delete document.documentElement.dataset.theme")
    system_dark = page.evaluate_script("matchMedia('(prefers-color-scheme: dark)').matches")
    assert_equal system_dark ? "rgb(22, 22, 30)" : "rgb(246, 241, 230)", root_background

    { "light" => "rgb(246, 241, 230)", "dark" => "rgb(22, 22, 30)" }.each do |theme, expected|
      page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
      assert_equal expected, root_background
      assert_equal theme, page.evaluate_script("getComputedStyle(document.documentElement).colorScheme")
    end

    HANDS.each do |hand, face|
      page.execute_script(<<~JAVASCRIPT, hand)
        if (arguments[0]) document.documentElement.dataset.hand = arguments[0]
        else delete document.documentElement.dataset.hand
      JAVASCRIPT
      assert_includes computed_style(".page-shell", "fontFamily"), face
      assert_includes computed_style(".tab-bar", "fontFamily"), face
    end
  end

  test "global canvas leaves the password request state usable and T4-owned" do
    PROFILES.each do |width, theme, hand|
      visit new_password_path
      apply_profile(width:, theme:, hand:)

      assert_selector "h1", text: "Forgot your password?"
      assert_field "Email"
      assert_button "Email reset instructions"
      assert_no_selector ".page-shell"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "page shell preferences and fixed tab bar preserve both phone profiles" do
    sign_in

    PROFILES.each do |width, theme, hand|
      apply_profile(width:, theme:, hand:)
      assert_selector "main.page-shell > .page-shell__header:first-child .page-shell__title", text: "Daily Log"
      assert_equal "Daily Log", first_visible_text("main.page-shell")
      assert_button "Theme: system"
      assert_button "Hand: marker"

      geometry = page.evaluate_script(<<~JAVASCRIPT)
        (() => {
          const shell = document.querySelector(".page-shell").getBoundingClientRect()
          const tabs = document.querySelector(".tab-bar").getBoundingClientRect()
          const items = [...document.querySelectorAll(".tab-bar__item")].map((item) => item.getBoundingClientRect())
          const style = getComputedStyle(document.querySelector(".tab-bar"))
          return { shell, tabs, items, position: style.position, bottom: parseFloat(style.bottom) }
        })()
      JAVASCRIPT
      assert_in_delta 0, geometry.dig("shell", "x"), 0.25
      assert_in_delta width, geometry.dig("shell", "width"), 0.25
      assert_equal "16px", computed_style(".page-shell", "paddingLeft")
      assert_equal "16px", computed_style(".page-shell", "paddingRight")
      assert_equal "fixed", geometry.fetch("position")
      assert_in_delta 65, geometry.dig("tabs", "height"), 0.25
      assert_in_delta width, geometry.dig("tabs", "width"), 0.25
      assert_operator geometry.fetch("bottom"), :>=, 0
      assert_equal 4, geometry.fetch("items").size
      geometry.fetch("items").each do |item|
        assert_in_delta width / 4.0, item.fetch("width"), 0.25
        assert_operator item.fetch("height"), :>=, 44
      end
      assert_selector ".tab-bar__item--active[aria-current='page']", text: "Today", count: 1
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "semantic hidden focus targets and native date control stay truthful" do
    task = Entry.capture!(
      "shared primitive task", user: @user, today: Time.zone.today, as_of: Time.zone.today,
      page_kind: "daily", page_on: Time.zone.today
    )
    sign_in
    apply_profile(width: 320, theme: "dark", hand: "architects-daughter")

    assert_selector "#rapid_log_panel[hidden]", visible: :all
    assert_equal "none", computed_style("#rapid_log_panel", "display")
    assert_selector "#entry_#{task.id} .entry__action-strip[hidden]", visible: :all
    assert_equal "none", computed_style("#entry_#{task.id} .entry__action-strip", "display")

    find("#entry_#{task.id} .entry__toggle").click
    within "#entry_#{task.id}" do
      click_button "Schedule…", exact: true
      field = find_field("Schedule for")
      assert_equal "date", field[:type]
      assert_selector "input.field[type='date']"
      assert_operator field.rect.width, :>=, 44
      assert_operator field.rect.height, :>=, 44
      assert_not_equal "none", page.evaluate_script("getComputedStyle(arguments[0]).appearance", field)
      page.execute_script("arguments[0].focus()", field)
      assert field.matches_css?(":focus-visible")
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(arguments[0]).outlineWidth)", field), :>=, 2
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "notices errors and empty states keep roles wording and recorded geometry" do
    task = Entry.capture!(
      "refusal geometry task", user: @user, today: Time.zone.today, as_of: Time.zone.today,
      page_kind: "daily", page_on: Time.zone.today
    )
    sign_in
    apply_profile(width: 390, theme: "light", hand: "rock-salt")
    find("#entry_#{task.id} .entry__toggle").click
    task.complete!
    within("#entry_#{task.id}") { click_button "Complete" }

    assert_selector ".notice.notice--alert[role='alert']", text: "That entry can't do that."
    box = find(".notice--alert").rect
    assert_in_delta 32, box.x, 0.5
    assert_in_delta 326, box.width, 0.5
    assert_operator box.height, :>=, 44

    @user.entries.update_all(deleted_at: Time.current)
    visit root_path
    assert_selector ".state-text", text: "Nothing logged yet."

    visit journal_index_path
    find("#new_collection_toggle").click
    click_button "Create", exact: true
    assert_selector ".state-text.form-errors", text: "Name can't be blank"
    assert_equal resolved_color("--warn"), computed_style(".form-errors", "color")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "Rapid Log keeps selected-kind synchronization form semantics and target sizes" do
    sign_in

    PROFILES.each do |width, theme, hand|
      visit root_path
      apply_profile(width:, theme:, hand:)
      find("#capture_reveal").click
      assert_selector "form.rapid-log"
      assert_selector "button[aria-label='Task'][aria-pressed='true'].rapid-log__kind--selected"
      assert_equal "task", find("input[name='default_kind']", visible: :all).value

      find("button[aria-label='Event']").click
      assert_selector "button[aria-label='Event'][aria-pressed='true'].rapid-log__kind--selected"
      assert_selector "button[aria-label='Task'][aria-pressed='false']"
      assert_equal "event", find("input[name='default_kind']", visible: :all).value
      %w[Task Event Note].each do |label|
        box = find("button[aria-label='#{label}']").rect
        assert_in_delta 44, box.width, 0.25
        assert_in_delta 44, box.height, 0.25
      end
      assert_operator find_field("Rapid log…").rect.height, :>=, 44
      assert_operator find_button("Log", exact: true).rect.height, :>=, 44
      find("#capture_reveal", visible: :all).click
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def apply_profile(width:, theme:, hand:)
    page.current_window.resize_to(width, 844)
    page.execute_script(<<~JAVASCRIPT, theme, hand)
      document.documentElement.dataset.theme = arguments[0]
      document.documentElement.dataset.hand = arguments[1]
    JAVASCRIPT
  end

  def root_background
    page.evaluate_script("getComputedStyle(document.documentElement).backgroundColor")
  end

  def resolved_color(variable)
    page.evaluate_script(<<~JAVASCRIPT, variable)
      (() => {
        const probe = document.createElement("span")
        probe.style.color = `var(${arguments[0]})`
        document.body.appendChild(probe)
        const color = getComputedStyle(probe).color
        probe.remove()
        return color
      })()
    JAVASCRIPT
  end

  def computed_style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]", selector, property)
  end

  def first_visible_text(selector)
    page.evaluate_script(<<~JAVASCRIPT, selector)
      (() => {
        const root = document.querySelector(arguments[0])
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
        while (walker.nextNode()) {
          const text = walker.currentNode.textContent.trim()
          const parent = walker.currentNode.parentElement
          if (text && parent.getClientRects().length && getComputedStyle(parent).visibility !== "hidden") return text
        }
      })()
    JAVASCRIPT
  end
end
