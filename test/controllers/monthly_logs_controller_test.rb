require "test_helper"

class MonthlyLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "missing and invalid months render the current calendar" do
    [ nil, "not-a-month", "2026-13", "1900-01junk" ].each do |month|
      get month ? monthly_log_path(month: month) : monthly_log_path

      assert_response :success
      assert_select ".month-navigation .day-navigation__viewed-day", text: formatted_month(Time.zone.today)
      assert_select ".monthly-log__view-link[aria-current='page']", text: "Calendar"
    end
  end

  test "far months render and only tasks selects the task view" do
    [ Date.new(1900, 1, 1), Date.new(2200, 12, 1) ].each do |month|
      get monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks")

      assert_response :success
      assert_select ".month-navigation .day-navigation__viewed-day", text: formatted_month(month)
      assert_select ".monthly-log__view-link[aria-current='page']", text: "Tasks"
    end

    get monthly_log_path(month: Time.zone.today.strftime("%Y-%m"), view: "crafted")
    assert_response :success
    assert_select ".monthly-log__view-link[aria-current='page']", text: "Calendar"
  end

  test "task counts compose open tasks and exclude other months" do
    month = Date.new(2027, 1, 1)
    open_task = create_open_task("open this month", page_on: month, page_kind: "monthly_tasks")
    done_task = create_open_task("done this month", page_on: month, page_kind: "monthly_tasks")
    done_task.complete!
    other_month = create_open_task("outside month", page_on: month.next_month, page_kind: "monthly_tasks")

    get monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks")

    assert_response :success
    assert_select ".monthly-task-count", text: "1 open · 2 logged"
    assert_select "#monthly_task_#{open_task.id}"
    assert_select "#monthly_task_#{done_task.id}"
    assert_select "#monthly_task_#{other_month.id}", count: 0
  end

  test "calendar glyphs follow the active hand" do
    month = Date.new(2027, 1, 1)
    event = create_event("monthly circle", occurs_on: month + 4.days)

    get monthly_log_path(month: month.strftime("%Y-%m"))
    assert_select "#monthly_entry_#{event.id} .entry__glyph", text: "O"

    patch lettering_path, params: { hand: "sans" }
    get monthly_log_path(month: month.strftime("%Y-%m"))
    assert_select "#monthly_entry_#{event.id} .entry__glyph", text: "○"
  end

  test "calendar renders one row per day with every resident and keeps bare days" do
    month = Date.new(2027, 1, 1)
    populated_day = month + 4.days
    bare_day = month + 5.days
    create_event("first event", occurs_on: populated_day)
    create_event("second event", occurs_on: populated_day)

    get monthly_log_path(month: month.strftime("%Y-%m"))

    populated_selector = ".monthly-calendar__day[data-date='#{populated_day.iso8601}']"
    assert_select populated_selector, count: 1 do
      assert_select ".entry__text", count: 2
    end
    assert_select "#{populated_selector} .monthly-calendar__number", text: populated_day.day.to_s, count: 1
    assert_select ".monthly-calendar__day[data-date='#{bare_day.iso8601}']", count: 1 do
      assert_select ".entry__text", count: 0
    end
  end

  private

  def create_event(text, occurs_on:)
    @user.entries.create!(
      kind: "event",
      state: nil,
      text: text,
      tags: [],
      page_kind: "monthly_calendar",
      page_on: occurs_on.beginning_of_month,
      occurs_on: occurs_on
    )
  end

  def formatted_month(month)
    month.strftime("%b · %Y").upcase
  end
end
