require "application_system_test_case"

# Exercises every ruled Daily Log flow through a real browser.
class DailyLogTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    # The browser lane owns the rows it observes; fixed-date fixtures cannot
    # make date navigation or relative count assertions time-dependent.
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "1 signing in lands on today's Daily Log" do
    sign_in

    assert_current_path root_path
    assert_text "Daily Log"
    assert_selector ".daily-log__eyebrow", text: formatted_day(Time.zone.today)
    assert_selector "[data-testid='open-count']", text: /\A\d+ open\z/
  end

  test "2 rapid logging a priority task appends it and returns focus to capture reveal" do
    sign_in
    open_count = displayed_open_count

    capture "* pack for the trip tomorrow 2pm +camping"
    task = @user.entries.find_by!(text: "pack for the trip")

    within entry_selector(task) do
      assert_text "*"
      assert_text "•"
      assert_text "pack for the trip"
      assert_text "14:00"
      assert_text "+camping"
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end
    assert_equal open_count + 1, displayed_open_count
    assert_selector "#rapid_log_panel[hidden]", visible: :all
    assert_equal "capture_reveal", page.evaluate_script("document.activeElement.id")
    action_strip_id = "entry_#{task.id}_actions"
    assert_selector "button.entry__toggle[type='button'][aria-expanded='false'][aria-controls='#{action_strip_id}']"
    assert_selector "##{action_strip_id}[hidden]", visible: :all

    reveal_actions(task)
    within entry_selector(task) do
      assert_selector ".entry__toggle[aria-expanded='true']"
      assert_selector "##{action_strip_id}:not([hidden])"
      assert_button "Complete"
      assert_button "Strike"
      assert_button "Migrate"
      assert_button "Schedule…", exact: true
    end

    reveal_actions(task)
    within entry_selector(task) do
      assert_selector ".entry__toggle[aria-expanded='false']"
      assert_selector "##{action_strip_id}[hidden]", visible: :all
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end
  end

  test "3 the kind toggle captures events and notes without task actions" do
    sign_in

    reveal_capture
    find("button[aria-label='Event']").click
    capture "standup 9am"
    event = @user.entries.find_by!(text: "standup")

    within entry_selector(event) do
      assert_text "O"
      assert_text "09:00"
      assert_no_selector ".entry__toggle"
      find(".entry__line").click
      assert_no_selector ".entry__action-strip"
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end

    reveal_capture
    find("button[aria-label='Note']").click
    capture "quiet observation"
    note = @user.entries.find_by!(text: "quiet observation")

    within entry_selector(note) do
      assert_text "–"
      assert_no_selector ".entry__toggle"
      find(".entry__line").click
      assert_no_selector ".entry__action-strip"
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end
  end

  test "opening a second task closes the first task's actions" do
    sign_in
    capture "first calm task"
    first_task = @user.entries.find_by!(text: "first calm task")
    capture "second calm task"
    second_task = @user.entries.find_by!(text: "second calm task")

    reveal_actions(first_task)
    assert_selector "#{entry_selector(first_task)}.entry--selected"
    within entry_selector(first_task) do
      assert_button "Complete"
      click_button "Schedule…", exact: true
      assert_field "Schedule date"
    end

    reveal_actions(second_task)
    assert_no_selector "#{entry_selector(first_task)}.entry--selected"
    within(entry_selector(first_task)) { assert_no_button "Complete" }
    assert_selector "#{entry_selector(second_task)}.entry--selected"
    within(entry_selector(second_task)) { assert_button "Complete" }

    reveal_actions(first_task)
    within entry_selector(first_task) do
      assert_button "Complete"
      assert_button "Schedule…", exact: true
      assert_no_field "Schedule date"
    end
  end

  test "4 a task can be completed and reopened" do
    sign_in
    capture "round trip task"
    task = @user.entries.find_by!(text: "round trip task")
    open_count = displayed_open_count

    reveal_actions(task)
    within(entry_selector(task)) { click_button "Complete" }
    assert_selector "#{entry_selector(task)}.entry--muted"
    assert_equal open_count - 1, displayed_open_count

    reveal_actions(task)
    within entry_selector(task) do
      assert_text "x"
      assert_button "Reopen"
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
      click_button "Reopen"
    end

    assert_selector "#{entry_selector(task)} .entry__glyph", text: "•"
    assert_equal open_count, displayed_open_count
  end

  test "5 striking a task crosses out its text but not its bullet" do
    sign_in
    capture "obsolete task"
    task = @user.entries.find_by!(text: "obsolete task")

    reveal_actions(task)
    within(entry_selector(task)) { click_button "Strike" }
    assert_selector "#{entry_selector(task)} .entry__text--struck"

    within entry_selector(task) do
      assert_text "•"
      text_decoration = page.evaluate_script(
        "getComputedStyle(document.querySelector('#{entry_selector(task)} .entry__text')).textDecorationLine"
      )
      assert_includes text_decoration, "line-through"
    end

    reveal_actions(task)
    within entry_selector(task) do
      assert_button "Reopen"
      assert_no_button "Complete"
      assert_no_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end
  end

  test "6 scheduling and migrating show their destinations" do
    sign_in
    scheduled_on = Time.zone.today + 7.days

    capture "scheduled task"
    scheduled_task = @user.entries.find_by!(text: "scheduled task", migrated_from_id: nil)

    reveal_actions(scheduled_task)
    within entry_selector(scheduled_task) do
      click_button "Schedule…", exact: true
      assert_field "Schedule date"
      find("button[aria-label='Cancel scheduling']").click
      assert_no_field "Schedule date"
      assert_button "Schedule…", exact: true

      click_button "Schedule…", exact: true
      set_date_field "Schedule date", scheduled_on
      click_button "Schedule", exact: true
    end
    assert_selector "#{entry_selector(scheduled_task)} .entry__glyph", text: "<"
    within entry_selector(scheduled_task) do
      assert_no_selector ".entry__toggle"
      assert_text "→ #{formatted_destination(scheduled_on)}"
    end

    capture "migrated task"
    migrated_task = @user.entries.find_by!(text: "migrated task", migrated_from_id: nil)
    reveal_actions(migrated_task)
    within(entry_selector(migrated_task)) { click_button "Migrate" }
    migration_day = Time.zone.today.next_month.beginning_of_month
    assert_selector "#{entry_selector(migrated_task)} .entry__glyph", text: ">"
    within entry_selector(migrated_task) do
      assert_no_selector ".entry__toggle"
      assert_text "→ #{formatted_destination(migration_day)}"
    end
  end

  test "7 previous-day navigation captures on that page and uses the Today tab to return" do
    sign_in
    previous_day = Time.zone.today - 1.day

    find("a[aria-label='Previous day']").click

    assert_selector ".daily-log__eyebrow", text: formatted_day(previous_day)
    assert_text "Nothing logged yet."
    assert_selector ".day-navigation__viewed-day", text: formatted_day(previous_day)
    assert_no_link "today", exact: true

    reveal_capture
    assert_text "→ logging to #{formatted_destination(previous_day)}"
    capture "written on yesterday"
    captured = @user.entries.find_by!(text: "written on yesterday")
    assert_equal previous_day, captured.logged_on
    assert_text "written on yesterday"

    click_link "Today", exact: true
    assert_current_path root_path
    assert_no_text "written on yesterday"
  end

  test "8 theme choice cycles through dark and persists before returning to system" do
    sign_in

    click_button "Theme: system"
    assert_selector "html[data-theme='light']", visible: :all
    light_background = page.evaluate_script("getComputedStyle(document.documentElement).backgroundColor")
    click_button "Theme: light"
    assert_selector "html[data-theme='dark']", visible: :all
    dark_background = page.evaluate_script("getComputedStyle(document.documentElement).backgroundColor")
    refute_equal light_background, dark_background

    refresh
    assert_selector "html[data-theme='dark']", visible: :all

    click_button "Theme: dark"
    assert_no_selector "html[data-theme]", visible: :all
  end

  test "hand choice cycles through every face and returns to marker" do
    sign_in

    assert_no_selector "html[data-hand]", visible: :all
    assert_button "Hand: marker", exact: true
    marker_font = title_font_family
    sans_font = nil
    hand_steps = [
      [ "Hand: marker", "rock-salt", "Hand: rock salt" ],
      [ "Hand: rock salt", "architects-daughter", "Hand: architects" ],
      [ "Hand: architects", "patrick-hand", "Hand: patrick" ],
      [ "Hand: patrick", "gochi-hand", "Hand: gochi" ],
      [ "Hand: gochi", "sans", "Hand: sans" ],
      [ "Hand: sans", nil, "Hand: marker" ]
    ]

    hand_steps.each do |current_label, stored_hand, next_label|
      click_button current_label, exact: true

      if stored_hand
        assert_selector "html[data-hand='#{stored_hand}']", visible: :all
        sans_font = title_font_family if stored_hand == "sans"
        refresh
        assert_selector "html[data-hand='#{stored_hand}']", visible: :all
      else
        assert_no_selector "html[data-hand]", visible: :all
      end
      assert_button next_label, exact: true
    end

    refute_equal marker_font, sans_font
  end

  test "theme and hand choices compose" do
    sign_in

    click_button "Theme: system", exact: true
    click_button "Theme: light", exact: true
    click_button "Hand: marker", exact: true

    assert_selector "html[data-theme='dark'][data-hand='rock-salt']", visible: :all
  end

  test "9 an invalid daily-log date renders today" do
    sign_in

    visit daily_log_path(date: "not-a-date")

    assert_selector ".daily-log__eyebrow", text: formatted_day(Time.zone.today)
    assert_text "Daily Log"
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def capture(line)
    reveal_capture unless page.has_field?("Rapid log…")
    fill_in "Rapid log…", with: line
    find_field("Rapid log…").send_keys(:enter)
    assert_selector "#rapid_log_panel[hidden]", visible: :all
    assert_field "Rapid log…", with: "", visible: :all
  end

  def reveal_capture
    find("button[aria-label='Write on this page']").click
    assert_field "Rapid log…"
  end

  def displayed_open_count
    find("[data-testid='open-count']").text.to_i
  end

  def reveal_actions(entry)
    within(entry_selector(entry)) { find(".entry__toggle").click }
  end

  def set_date_field(label, date)
    field = find_field(label)
    page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end

  def formatted_day(date)
    date.strftime("%a · %b %-d").upcase
  end

  def formatted_destination(date)
    date.strftime("%b %-d").upcase
  end

  def title_font_family
    page.evaluate_script("getComputedStyle(document.querySelector('.daily-log h1')).fontFamily")
  end
end
