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
    reveal_daily_capture
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
    assert_equal viewed_day, captured.logged_on
    assert_selector "[data-testid='open-count']", text: "1 open"

    reveal_actions(captured)
    within("#entry_#{captured.id}") { click_button "Migrate", exact: true }
    assert_selector "#entry_#{captured.id} .entry__glyph", text: ">"
    assert_equal viewed_day.next_month.beginning_of_month, captured.reload.successor.logged_on

    refresh
    assert_text "page-bound task"
    click_link "Today", exact: true
    assert_current_path root_path
    assert_no_text "page-bound task"
  end

  test "4 a weekday token resolves against the future page being written on" do
    sign_in
    viewed_day = Time.zone.today + 10.days
    expected_friday = viewed_day + ((5 - viewed_day.wday) % 7).days
    visit daily_log_path(date: viewed_day.iso8601)

    reveal_daily_capture
    submit_daily_capture "page-relative friday"

    captured = @user.entries.find_by!(text: "page-relative")
    assert_equal viewed_day, captured.logged_on
    assert_equal expected_friday, captured.occurs_on
  end

  test "5 Future Log adds under one month at a time and places the entry on its calendar day" do
    first_month = Time.zone.today.next_month.beginning_of_month
    create_future_entry("later twentieth", first_month + 19.days)
    create_future_entry("later twenty-fifth", first_month + 24.days)
    sign_in
    visit future_log_path
    second_month = first_month.next_month

    reveal_future_month(first_month)
    assert_equal future_day_field_id(first_month), active_element_id
    reveal_future_month(second_month)
    assert_future_month_closed(first_month)
    reveal_future_month(first_month)

    target_day = first_month + 4.days
    within future_month(first_month) do
      find("input[aria-label='Day of the month']").fill_in(with: target_day.day)
      find("input[aria-label='Entry text']").fill_in(with: "○ future dentist 9am")
      click_button "Log", exact: true
    end

    assert_text "future dentist"
    captured = @user.entries.find_by!(text: "future dentist")
    assert_equal [ target_day, target_day ], [ captured.logged_on, captured.occurs_on ]
    assert_selector "#future_entry_#{captured.id}", text: "future dentist"
    assert_equal %w[5 20 25], all("#{future_month(first_month)} .future-entry__day").map(&:text)
    assert_future_month_closed(first_month)
    assert_equal future_month_toggle_id(first_month), active_element_id

    visit monthly_log_path(month: first_month.strftime("%Y-%m"))
    within ".monthly-calendar__day[data-date='#{target_day.iso8601}']" do
      assert_text "future dentist"
    end
  end

  test "6 Future Log refuses an impossible day without losing the open add row" do
    sign_in
    visit future_log_path
    target_month = Time.zone.today.next_month.beginning_of_month

    reveal_future_month(target_month)
    within future_month(target_month) do
      find("input[aria-label='Day of the month']").fill_in(with: 32)
      find("input[aria-label='Entry text']").fill_in(with: "impossible future entry")
      click_button "Log", exact: true
    end

    assert_current_path future_log_path
    assert_text "That entry can't do that."
    assert_nil @user.entries.find_by(text: "impossible future entry")
    assert_selector "#{future_month(target_month)} .future-log__add-row:not([hidden])"
  end

  test "7 existing actions, preferences, and tabs work while capture stays hidden" do
    task = Entry.capture!("hidden-bar task", user: @user, today: Time.zone.today)
    sign_in

    assert_hidden_daily_capture
    reveal_actions(task)
    within("#entry_#{task.id}") { click_button "Complete", exact: true }
    assert_selector "#entry_#{task.id}.entry--muted"
    assert_hidden_daily_capture

    click_button "Theme: system", exact: true
    assert_selector "html[data-theme='light']", visible: :all
    click_button "Hand: marker", exact: true
    assert_selector "html[data-hand='rock-salt']", visible: :all
    click_link "Future", exact: true
    assert_current_path future_log_path
    assert_active_tab "Future"
  end

  private

  def sign_in
    sign_in_through_browser(@user)
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

  def reveal_future_month(month)
    within future_month(month) do
      find_button(formatted_month(month), exact: true).click
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
    entry = Entry.capture!(text, user: @user, today: date)
    entry.update!(occurs_on: date)
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
end
