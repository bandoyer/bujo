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

    assert_link "Today", exact: true, href: root_path
    assert_active_tab "Today"
    assert_selector ".tab-bar__icon[aria-hidden='true'][focusable='false']", count: 4
    click_link "Month", exact: true
    assert_current_path monthly_log_path
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today)
    assert_active_tab "Month"
    assert_no_field "Rapid log…"

    click_link "Future", exact: true
    assert_current_path future_log_path
    assert_text "Future Log"
    assert_active_tab "Future"
    assert_no_selector ".monthly-log__views"
    assert_no_selector ".month-navigation"

    click_link "Today", exact: true
    assert_current_path root_path
    assert_active_tab "Today"
    assert_button "Index", exact: true, disabled: true
    assert_no_link "Index", exact: true
  end

  test "2 today is highlighted without deriving Calendar residency from a Daily event" do
    sign_in
    reveal_capture
    find("button[aria-label='Event']").click
    capture "monthly standup today 9am"

    click_link "Month", exact: true

    assert_selector "#{calendar_day(Time.zone.today)}.monthly-calendar__day--today"
    within calendar_day(Time.zone.today) do
      assert_no_text "monthly standup"
    end
    click_link "Today", exact: true
    assert_text "monthly standup"
  end

  test "3 a scheduled task waits only in the future runway" do
    sign_in
    scheduled_on = Time.zone.today.next_month.beginning_of_month + 6.days
    capture "runway task 2pm"
    task = @user.entries.find_by!(text: "runway task", migrated_from_id: nil)
    schedule_task(task, scheduled_on)

    click_link "Month", exact: true
    find("a[aria-label='Next month']").click
    within calendar_day(scheduled_on) do
      assert_no_text "runway task"
    end

    click_link "Future", exact: true
    within future_month(scheduled_on) do
      assert_text "runway task"
      assert_text scheduled_on.day.to_s
      assert_text "14:00"
      assert_selector ".entry__glyph", text: "•"
    end
  end

  test "4 calendar day rows open that day's Daily Log" do
    sign_in
    target_day = Time.zone.today.beginning_of_month
    click_link "Month", exact: true

    find("#{calendar_day(target_day)} .monthly-calendar__date-link").click

    assert_current_path daily_log_path(date: target_day.iso8601)
    assert_selector ".daily-log__eyebrow", text: formatted_day(target_day)
  end

  test "5 month navigation preserves the Tasks view; the Month tab returns" do
    sign_in
    click_link "Month", exact: true
    click_link "Tasks", exact: true
    assert_tasks_view

    find("a[aria-label='Previous month']").click
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today.prev_month)
    assert_tasks_view
    assert_no_link "this month"

    find("a[aria-label='Next month']").click
    find("a[aria-label='Next month']").click
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today.next_month)
    assert_tasks_view

    click_link "Month", exact: true
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today)
  end

  test "6 Tasks shows full task history and a composed open count" do
    month = Time.zone.today.beginning_of_month
    task = create_monthly_task("finish monthly slice", month)
    struck_task = create_monthly_task("obsolete monthly task", month)
    struck_task.strike!
    sign_in
    click_link "Month", exact: true
    click_link "Tasks", exact: true
    initial_open_count = displayed_month_open_count
    assert_no_field "Rapid log…"
    within "#monthly_task_#{task.id}" do
      assert_text "finish monthly slice"
      assert_selector ".entry__toggle"
      assert_no_button "Complete"
    end
    within "#monthly_task_#{struck_task.id}" do
      assert_selector ".entry__text--struck"
      text_decoration = page.evaluate_script(
        "getComputedStyle(document.querySelector('#monthly_task_#{struck_task.id} .entry__text')).textDecorationLine"
      )
      assert_includes text_decoration, "line-through"
    end

    reveal_actions(task)
    within(entry_selector(task)) { click_button "Complete" }

    assert_selector "#monthly_task_#{task.id} #entry_#{task.id}.entry--muted"
    within("#monthly_task_#{task.id}") { assert_text "x" }
    assert_equal initial_open_count - 1, displayed_month_open_count
    assert_text "2 logged"
  end

  test "7 migration creates one resident on next month's Tasks page" do
    sign_in
    capture "carry this task"
    task = @user.entries.find_by!(text: "carry this task", migrated_from_id: nil)
    reveal_actions(task)
    within(entry_selector(task)) { click_button "Migrate" }
    assert_selector "#{entry_selector(task)} .entry__glyph", text: ">"
    destination = Time.zone.today.next_month.beginning_of_month
    successor = @user.entries.find_by!(migrated_from_id: task.id)

    click_link "Month", exact: true
    find("a[aria-label='Next month']").click
    click_link "Tasks", exact: true

    assert_no_selector "#monthly_task_#{task.id}"
    within "#monthly_task_#{successor.id}" do
      assert_text "carry this task"
      assert_selector ".entry__toggle"
    end
    click_link "Today", exact: true
    within entry_selector(task) do
      assert_text ">"
      assert_text "→ #{formatted_destination(destination)}"
    end
  end

  test "8 Future shows a six-month runway and residents do not open Daily Logs" do
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
    assert_current_path future_log_path
    visit daily_log_path(date: scheduled_on.iso8601)
    assert_no_text "future runway link"
  end

  test "9 crafted month and view values fall back to the current calendar" do
    sign_in

    visit monthly_log_path(month: "not-a-month")
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today)
    assert_calendar_view

    visit monthly_log_path(month: Time.zone.today.strftime("%Y-%m"), view: "garbage")
    assert_selector ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today)
    assert_calendar_view
  end

  test "10 Calendar capture creates residents without touching Daily or Tasks pages" do
    sign_in
    day = Time.zone.today
    click_link "Month", exact: true

    within calendar_day(day) do
      find("button[aria-label='Write on Calendar for #{day.strftime('%B %-d')}']").click
      assert_no_button "Note"
      fill_in "Rapid log…", with: "calendar-only task"
      click_button "Log", exact: true
    end
    assert_text "calendar-only task"
    task = @user.entries.find_by!(text: "calendar-only task")
    assert_equal [ "monthly_calendar", day.beginning_of_month, day ],
      [ task.page_kind, task.page_on, task.occurs_on ]

    visit daily_log_path(date: day.iso8601)
    assert_no_text "calendar-only task"
    visit monthly_log_path(month: day.strftime("%Y-%m"), view: "tasks")
    assert_no_text "calendar-only task"
  end

  test "11 Monthly Tasks captures tasks in place and future pages stay capture-closed" do
    sign_in
    click_link "Month", exact: true
    click_link "Tasks", exact: true

    find("button[aria-label='Write on Monthly Tasks']").click
    assert_no_button "Event"
    assert_no_button "Note"
    fill_in "Rapid log…", with: "curated inventory"
    click_button "Log", exact: true
    assert_text "curated inventory"
    assert_equal "monthly_tasks", @user.entries.find_by!(text: "curated inventory").page_kind

    find("a[aria-label='Next month']").click
    assert_no_button "Write on Monthly Tasks"
    assert_no_field "Rapid log…"
  end

  test "12 overdue Future residents remain while only later months can add" do
    overdue = @user.entries.create!(
      kind: "event", state: nil, text: "overdue future event", tags: [],
      page_kind: "future", page_on: nil, occurs_on: Time.zone.today.prev_month.beginning_of_month
    )
    sign_in
    click_link "Future", exact: true

    overdue_month = future_month(overdue.occurs_on)
    within overdue_month do
      assert_text "overdue future event"
      assert_no_button formatted_future_month(overdue.occurs_on)
    end
    within future_month(Time.zone.today.next_month) do
      assert_button formatted_future_month(Time.zone.today.next_month)
    end
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

  def assert_active_tab(label)
    assert_selector ".tab-bar__item[aria-current='page']", count: 1
    assert_selector ".tab-bar__item[aria-current='page']", text: label, count: 1
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

  def formatted_future_month(date)
    date.strftime("%B %Y").upcase
  end

  def create_monthly_task(text, month)
    @user.entries.create!(
      kind: "task", state: "open", text: text, tags: [],
      page_kind: "monthly_tasks", page_on: month
    )
  end
end
