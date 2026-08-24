require "application_system_test_case"

# Exercises the Monthly and Future reading screens through their real links.
class MonthFutureLogsTest < ApplicationSystemTestCase
  RUNWAY_MONTHS = 6

  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "1 the tab bar navigates among live logs and leaves Index disabled" do
    sign_in

    assert_link "Today", exact: true
    click_link "Month", exact: true
    assert_current_path monthly_log_path
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today)

    click_link "Future", exact: true
    assert_current_path future_log_path
    assert_text "Future Log"

    click_link "Today", exact: true
    assert_current_path root_path
    assert_button "Index", exact: true, disabled: true
    assert_no_link "Index", exact: true
  end

  test "2 today is highlighted and carries today's timed event" do
    sign_in
    find("button[aria-label='Event']").click
    capture "monthly standup today 9am"

    click_link "Month", exact: true

    assert_selector "#{calendar_day(Time.zone.today)}.monthly-calendar__day--today"
    within calendar_day(Time.zone.today) do
      assert_text "monthly standup"
      assert_text "09:00"
      assert_text "O"
    end
  end

  test "3 a scheduled task appears in next month's calendar and the future runway" do
    sign_in
    scheduled_on = Time.zone.today.next_month.beginning_of_month + 6.days
    capture "runway task"
    task = @user.entries.find_by!(text: "runway task", migrated_from_id: nil)
    schedule_task(task, scheduled_on)

    click_link "Month", exact: true
    find("a[aria-label='Next month']").click
    within calendar_day(scheduled_on) do
      assert_text "runway task"
      assert_text scheduled_on.day.to_s
    end

    click_link "Future", exact: true
    within future_month(scheduled_on) do
      assert_text "runway task"
      assert_text scheduled_on.day.to_s
    end
  end

  test "4 calendar day rows open that day's Daily Log" do
    sign_in
    target_day = Time.zone.today.beginning_of_month
    click_link "Month", exact: true

    find(calendar_day(target_day)).click

    assert_current_path daily_log_path(date: target_day.iso8601)
    assert_selector ".daily-log__eyebrow", text: formatted_day(target_day)
  end

  test "5 month navigation preserves the Tasks view including this month" do
    sign_in
    click_link "Month", exact: true
    click_link "Tasks", exact: true
    assert_tasks_view

    find("a[aria-label='Previous month']").click
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today.prev_month)
    assert_tasks_view
    assert_link "this month"

    find("a[aria-label='Next month']").click
    find("a[aria-label='Next month']").click
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today.next_month)
    assert_tasks_view

    click_link "this month"
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today)
    assert_tasks_view
  end

  test "6 Tasks shows full task history and a composed open count" do
    sign_in
    capture "finish monthly slice"
    task = @user.entries.find_by!(text: "finish monthly slice")

    click_link "Month", exact: true
    click_link "Tasks", exact: true
    initial_open_count = displayed_month_open_count
    assert_no_field "Rapid log…"
    within "#monthly_task_#{task.id}" do
      assert_text "finish monthly slice"
      assert_no_selector ".entry__toggle"
      assert_no_button "Complete"
    end

    find("#monthly_task_#{task.id}").click
    reveal_actions(task)
    within(entry_selector(task)) { click_button "Complete" }
    click_link "Month", exact: true
    click_link "Tasks", exact: true

    assert_selector "#monthly_task_#{task.id}.entry--muted"
    within("#monthly_task_#{task.id}") { assert_text "x" }
    assert_equal initial_open_count - 1, displayed_month_open_count
    assert_text "1 logged"
  end

  test "7 migrated task history links to its day and shows its destination" do
    sign_in
    capture "carry this task"
    task = @user.entries.find_by!(text: "carry this task", migrated_from_id: nil)
    reveal_actions(task)
    within(entry_selector(task)) { click_button "Migrate" }
    destination = Time.zone.today.next_month.beginning_of_month

    click_link "Month", exact: true
    click_link "Tasks", exact: true

    assert_selector "a#monthly_task_#{task.id}[href='#{daily_log_path(date: Time.zone.today.iso8601)}']"
    within "#monthly_task_#{task.id}" do
      assert_text ">"
      assert_text "→ #{formatted_destination(destination)}"
      assert_no_selector ".entry__toggle"
      assert_no_button "Reopen"
    end
  end

  test "8 Future shows a six-month runway and entry rows open their days" do
    sign_in
    scheduled_on = Time.zone.today.next_month.beginning_of_month + 4.days
    capture "future runway link"
    task = @user.entries.find_by!(text: "future runway link", migrated_from_id: nil)
    schedule_task(task, scheduled_on)
    successor = task.reload.successor

    click_link "Future", exact: true

    assert_selector ".future-log__month", count: RUNWAY_MONTHS
    assert_selector ".future-log__month--empty", count: RUNWAY_MONTHS - 1
    assert_no_field "Rapid log…"
    within "#future_entry_#{successor.id}" do
      assert_no_selector ".entry__toggle"
      assert_no_button "Complete"
    end
    find("#future_entry_#{successor.id}").click
    assert_current_path daily_log_path(date: scheduled_on.iso8601)
    assert_selector ".daily-log__eyebrow", text: formatted_day(scheduled_on)
  end

  test "9 crafted month and view values fall back to the current calendar" do
    sign_in

    visit monthly_log_path(month: "not-a-month")
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today)
    assert_calendar_view

    visit monthly_log_path(month: Time.zone.today.strftime("%Y-%m"), view: "garbage")
    assert_selector ".monthly-log__eyebrow", text: formatted_month(Time.zone.today)
    assert_calendar_view
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def capture(line)
    fill_in "Rapid log…", with: line
    find_field("Rapid log…").send_keys(:enter)
    assert_field "Rapid log…", with: ""
  end

  def schedule_task(task, scheduled_on)
    reveal_actions(task)
    within entry_selector(task) do
      click_button "Schedule…", exact: true
      set_date_field "Schedule date", scheduled_on
      click_button "Schedule", exact: true
    end
    assert_selector "#{entry_selector(task)} .entry__glyph", text: "<"
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

  def assert_tasks_view
    assert_selector ".monthly-log__view-link[aria-current='page']", text: "Tasks"
  end

  def assert_calendar_view
    assert_selector ".monthly-log__view-link[aria-current='page']", text: "Calendar"
  end

  def displayed_month_open_count
    find(".monthly-task-count").text.to_i
  end

  def calendar_day(date)
    ".monthly-calendar__day[data-date='#{date.iso8601}']"
  end

  def future_month(date)
    ".future-log__month[data-month='#{date.strftime("%Y-%m")}']"
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end

  def formatted_day(date)
    date.strftime("%a · %b %-d").upcase
  end

  def formatted_month(date)
    date.strftime("%b · %Y").upcase
  end

  def formatted_destination(date)
    date.strftime("%b %-d").upcase
  end
end
