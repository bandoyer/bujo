require "application_system_test_case"

# Exercises placement gestures and their page-local capture semantics.
class PlacementCaptureTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "1 Daily Log reveals a focused bar, captures once, then hides and restores focus" do
    sign_in

    assert_hidden_daily_capture
    click_trailing_space_after("#entries", "#capture_reveal")
    assert_selector "#rapid_log_panel:not([hidden])"
    assert_button "Log", exact: true
    assert_equal "rapid-log-line", active_element_id

    submit_daily_capture "one deliberate bullet"
    captured = @user.entries.find_by!(text: "one deliberate bullet")

    assert_selector "#entry_#{captured.id}"
    assert_hidden_daily_capture
    assert_equal "capture_reveal", active_element_id
  end

  test "2 tapping the Daily Log writing region again hides the bar" do
    sign_in

    reveal_daily_capture
    find("button[aria-label='Write on this page']").click

    assert_hidden_daily_capture
  end

  test "Daily trailing space starts below rendered content and reaches the fixed tabs" do
    task = Entry.capture!(
      "A wrapped task whose words deliberately continue across more than one narrow phone line",
      user: @user, today: Time.zone.today, as_of: Time.zone.today,
      page_kind: "daily", page_on: Time.zone.today
    )
    sign_in

    [
      [ 390, "light", "rock-salt" ],
      [ 320, "dark", "architects-daughter" ]
    ].each do |width, theme, hand|
      page.current_window.resize_to(width, 844)
      set_preferences(theme:, hand:)
      visit root_path
      assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all

      geometry = trailing_surface_geometry("#entries", "#capture_reveal")
      assert_in_delta geometry.fetch("contentBottom"), geometry.fetch("revealTop"), 1
      assert_operator geometry.fetch("revealHeight"), :>=, 44
      assert_operator geometry.fetch("revealBottom"), :<=, geometry.fetch("tabsTop")

      click_trailing_space_after("#entries", "#capture_reveal")
      assert_equal "rapid-log-line", active_element_id
      find("#capture_reveal").click
      reveal_actions(task)

      geometry = trailing_surface_geometry("#entries", "#capture_reveal")
      assert_in_delta geometry.fetch("contentBottom"), geometry.fetch("revealTop"), 1
      assert_operator geometry.fetch("revealHeight"), :>=, 44
      assert_operator geometry.fetch("revealBottom"), :<=, geometry.fetch("tabsTop")

      click_trailing_space_after("#entries", "#capture_reveal")
      assert_equal "rapid-log-line", active_element_id
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "3 another day's page captures there and migrates from that viewed date" do
    sign_in
    viewed_day = Time.zone.today - 1.day
    visit daily_log_path(date: viewed_day.iso8601)

    assert_selector ".day-navigation__viewed-day", text: formatted_day(viewed_day)
    assert_no_link "today", exact: true

    reveal_daily_capture
    assert_selector ".daily-log__capture-cue", text: "→ logging to #{short_day(viewed_day)}"
    submit_daily_capture "page-bound task"
    captured = @user.entries.find_by!(text: "page-bound task")
    assert_equal viewed_day, captured.page_on
    assert_selector "[data-testid='open-count']", text: "1 open"

    reveal_actions(captured)
    within("#entry_#{captured.id}") { click_button "Migrate", exact: true }
    assert_selector "#entry_#{captured.id} .entry__glyph", text: ">"
    assert_equal viewed_day.next_month.beginning_of_month, captured.reload.successor.page_on

    refresh
    assert_text "page-bound task"
    click_link "Today", exact: true
    assert_current_path root_path
    assert_no_text "page-bound task"
  end

  test "a refused past-day action keeps the trailing writing boundary usable" do
    viewed_day = Time.zone.today - 1.day
    task = Entry.capture!(
      "stale past task", user: @user, today: viewed_day, as_of: Time.zone.today,
      page_kind: "daily", page_on: viewed_day
    )
    sign_in
    page.current_window.resize_to(390, 844)
    visit daily_log_path(date: viewed_day.iso8601)

    reveal_actions(task)
    task.complete!
    within("#entry_#{task.id}") { click_button "Complete" }
    assert_text "That entry can't do that."

    geometry = trailing_surface_geometry("#entries", "#capture_reveal")
    assert_in_delta geometry.fetch("contentBottom"), geometry.fetch("revealTop"), 1
    assert_operator geometry.fetch("revealBottom"), :<=, geometry.fetch("tabsTop")
    click_trailing_space_after("#entries", "#capture_reveal")
    assert_equal "rapid-log-line", active_element_id
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "4 a future Daily page renders an existing resident without a writing affordance" do
    viewed_day = Time.zone.today + 10.days
    resident = @user.entries.create!(
      kind: "task", state: "open", text: "already resident", tags: [],
      page_kind: "daily", page_on: viewed_day
    )
    sign_in
    visit daily_log_path(date: viewed_day.iso8601)

    assert_selector "#entry_#{resident.id}", text: "already resident"
    assert_no_button "Write on this page"
    assert_no_field "Rapid log…"
  end

  test "5 Future Log trailing space shares kind controls and restores the actual opener" do
    first_month = Time.zone.today.next_month.beginning_of_month
    create_future_entry("later twentieth", first_month + 19.days)
    create_future_entry("later twenty-fifth", first_month + 24.days)
    sign_in
    visit future_log_path
    second_month = first_month.next_month

    reveal_future_month(first_month, from: :trailing)
    assert_equal future_day_field_id(first_month), active_element_id
    reveal_future_month(second_month)
    assert_future_month_closed(first_month)
    reveal_future_month(first_month, from: :trailing)

    target_day = first_month + 4.days
    within future_month(first_month) do
      find("input[aria-label='Day of the month']").fill_in(with: target_day.day)
      assert_selector "button[aria-label='Task'][aria-pressed='true'].rapid-log__kind--selected"
      find("button[aria-label='Event']").click
      assert_selector "button[aria-label='Event'][aria-pressed='true'].rapid-log__kind--selected"
      assert_selector "button[aria-label='Task'][aria-pressed='false']"
      assert_equal "event", find(".future-log__add-row:not([hidden]) input[name='default_kind']", visible: :all).value
      assert_match(/line$/, active_element_id)
      find("input[placeholder='Rapid log…']").fill_in(with: "future dentist 9am")
      click_button "Log", exact: true
    end

    assert_text "future dentist"
    captured = @user.entries.find_by!(text: "future dentist")
    assert_equal [ nil, target_day ], [ captured.page_on, captured.occurs_on ]
    assert_equal "event", captured.kind
    assert_selector "#future_entry_#{captured.id}", text: "future dentist"
    assert_future_month_closed(first_month)
    assert_equal future_month_trailing_id(first_month), active_element_id

    reveal_future_month(first_month)
    target_task_day = first_month + 5.days
    within future_month(first_month) do
      find("input[aria-label='Day of the month']").fill_in(with: target_task_day.day)
      find("button[aria-label='Event']").click
      find("button[aria-label='Task']").click
      assert_selector "button[aria-label='Task'][aria-pressed='true'].rapid-log__kind--selected"
      assert_selector "button[aria-label='Event'][aria-pressed='false']"
      assert_equal "task", find(".future-log__add-row:not([hidden]) input[name='default_kind']", visible: :all).value
      assert_match(/line$/, active_element_id)
      find("input[placeholder='Rapid log…']").fill_in(with: "future campsite task")
      click_button "Log", exact: true
    end

    assert_text "future campsite task"
    task_capture = @user.entries.find_by!(text: "future campsite task")
    assert_equal [ "task", target_task_day ], [ task_capture.kind, task_capture.occurs_on ]
    assert_future_month_closed(first_month)
    assert_equal future_month_toggle_id(first_month), active_element_id
    assert_equal %w[5 6 20 25], all("#{future_month(first_month)} .future-entry__day").map(&:text)

    visit monthly_log_path(month: first_month.strftime("%Y-%m"))
    within ".monthly-calendar__day[data-date='#{target_day.iso8601}']" do
      assert_no_text "future dentist"
    end
    visit daily_log_path(date: target_day.iso8601)
    assert_no_text "future dentist"
  end

  test "6 Future Log refuses an impossible day without losing the open add row" do
    sign_in
    visit future_log_path
    target_month = Time.zone.today.next_month.beginning_of_month

    reveal_future_month(target_month)
    within future_month(target_month) do
      find("input[aria-label='Day of the month']").fill_in(with: 32)
      find("input[placeholder='Rapid log…']").fill_in(with: "impossible future entry")
      click_button "Log", exact: true
    end

    assert_current_path future_log_path
    assert_text "That entry can't do that."
    assert_nil @user.entries.find_by(text: "impossible future entry")
    assert_selector "#{future_month(target_month)} .future-log__add-row:not([hidden])"
  end

  test "7 existing actions, preferences, and tabs work while capture stays hidden" do
    task = Entry.capture!(
      "hidden-bar task", user: @user, today: Time.zone.today, as_of: Time.zone.today,
      page_kind: "daily", page_on: Time.zone.today
    )
    sign_in

    assert_hidden_daily_capture
    reveal_actions(task)
    within("#entry_#{task.id}") { click_button "Complete", exact: true }
    assert_no_selector "#entry_#{task.id}.entry--muted"
    assert_hidden_daily_capture

    click_button "Theme: system", exact: true
    assert_button "Theme: light", exact: true
    assert_selector "html[data-theme='light']", visible: :all
    click_button "Hand: marker", exact: true
    assert_button "Hand: rock salt", exact: true
    assert_selector "html[data-hand='rock-salt']", visible: :all
    click_link "Future", exact: true
    assert_current_path future_log_path
    assert_active_tab "Future"
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def set_preferences(theme:, hand:)
    visit root_path
    until page.has_selector?("html[data-theme='#{theme}']", visible: :all, wait: 0.2)
      find("button", text: /Theme:/).click
    end
    until page.has_selector?("html[data-hand='#{hand}']", visible: :all, wait: 0.2)
      find("button", text: /Hand:/).click
    end
  end

  def reveal_daily_capture
    find("button[aria-label='Write on this page']").click
    assert_selector "#rapid_log_panel:not([hidden])"
  end

  def submit_daily_capture(line)
    fill_in "Rapid log…", with: line
    click_button "Log", exact: true
    assert_hidden_daily_capture
    assert_field "Rapid log…", with: "", visible: :all
  end

  def assert_hidden_daily_capture
    assert_selector "#capture_reveal[aria-expanded='false']"
    assert_selector "#rapid_log_panel[hidden]", visible: :all
  end

  def reveal_future_month(month, from: :heading)
    within future_month(month) do
      if from == :trailing
        point = page.evaluate_script(<<~JAVASCRIPT)
          (() => {
            const reveal = document.querySelector("##{future_month_trailing_id(month)}").getBoundingClientRect()
            return { x: reveal.left + reveal.width / 2, y: reveal.top + 2 }
          })()
        JAVASCRIPT
        page.execute_script("document.elementFromPoint(arguments[0], arguments[1]).click()",
          point.fetch("x"), point.fetch("y"))
      else
        find_button(formatted_month(month), exact: true).click
      end
      assert_selector ".future-log__add-row:not([hidden])"
    end
  end

  def assert_future_month_closed(month)
    assert_selector "#{future_month(month)} button[aria-expanded='false']"
    assert_selector "#{future_month(month)} .future-log__add-row[hidden]", visible: :all
  end

  def reveal_actions(entry)
    within("#entry_#{entry.id}") { find(".entry__toggle").click }
  end

  def create_future_entry(text, date)
    Entry.capture!(
      text, user: @user, today: date, as_of: Time.zone.today,
      page_kind: "future", page_on: nil, occurs_on: date
    )
  end

  def assert_active_tab(label)
    assert_selector ".tab-bar__item[aria-current='page']", text: label, count: 1
  end

  def active_element_id
    page.evaluate_script("document.activeElement.id")
  end

  def future_month(month)
    ".future-log__month[data-month='#{month.strftime('%Y-%m')}']"
  end

  def future_month_toggle_id(month)
    "future_month_#{month.strftime('%Y_%m')}_toggle"
  end

  def future_month_trailing_id(month)
    "future_month_#{month.strftime('%Y_%m')}_trailing_toggle"
  end

  def future_day_field_id(month)
    "future_month_#{month.strftime('%Y_%m')}_day"
  end

  def formatted_day(date)
    date.strftime("%a · %b %-d").upcase
  end

  def formatted_month(date)
    date.strftime("%B %Y").upcase
  end

  def short_day(date)
    date.strftime("%b %-d").upcase
  end

  def click_trailing_space_after(content_selector, reveal_selector)
    point = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const content = document.querySelector(#{content_selector.to_json}).getBoundingClientRect()
        const reveal = document.querySelector(#{reveal_selector.to_json}).getBoundingClientRect()
        return { x: reveal.left + (reveal.width / 2), y: Math.max(content.bottom + 2, reveal.top + 2) }
      })()
    JAVASCRIPT
    page.execute_script("document.elementFromPoint(arguments[0], arguments[1]).click()", point.fetch("x"), point.fetch("y"))
  end

  def trailing_surface_geometry(content_selector, reveal_selector)
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const content = document.querySelector(#{content_selector.to_json}).getBoundingClientRect()
        const reveal = document.querySelector(#{reveal_selector.to_json}).getBoundingClientRect()
        const tabs = document.querySelector(".tab-bar").getBoundingClientRect()
        return {
          contentBottom: content.bottom,
          revealTop: reveal.top,
          revealBottom: reveal.bottom,
          revealHeight: reveal.height,
          tabsTop: tabs.top
        }
      })()
    JAVASCRIPT
  end
end
