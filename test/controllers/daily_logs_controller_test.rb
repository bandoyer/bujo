require "test_helper"

class DailyLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "shows the requested day and falls back to today for invalid dates" do
    requested_date = Time.zone.today - 2.days

    get daily_log_path(date: requested_date.iso8601)
    assert_response :success
    assert_select ".daily-log__eyebrow", text: requested_date.strftime("%a · %b %-d").upcase

    get daily_log_path(date: "not-a-date")
    assert_response :success
    assert_select ".daily-log__eyebrow", text: Time.zone.today.strftime("%a · %b %-d").upcase
  end

  test "counts every kept open task rendered in the day's nested tree" do
    requested_date = Date.new(2027, 1, 15)
    root = create_open_task("root", logged_on: requested_date)
    child = create_open_task("child", logged_on: requested_date + 1.day, parent: root)
    grandchild = create_open_task("grandchild", logged_on: requested_date + 2.days, parent: child)
    deleted_child = create_open_task("deleted", logged_on: requested_date, parent: root)
    deleted_child.soft_delete!

    get daily_log_path(date: requested_date.iso8601)

    assert_response :success
    assert_select "[data-testid='open-count']", text: "3 open"
    assert_select "#entry_#{root.id} #entry_#{child.id} #entry_#{grandchild.id}"
    assert_select "#entry_#{deleted_child.id}", count: 0
  end

  test "header count ignores nested done tasks and notes" do
    requested_date = Date.new(2027, 1, 15)
    root = create_open_task("root", logged_on: requested_date)
    done_child = create_open_task("done child", logged_on: requested_date, parent: root)
    done_child.complete!
    note = @user.entries.create!(
      kind: "note",
      state: nil,
      text: "a nested note",
      tags: [],
      logged_on: requested_date,
      parent: root
    )

    get daily_log_path(date: requested_date.iso8601)

    assert_response :success
    assert_select "[data-testid='open-count']", text: "1 open"
    assert_select "#entry_#{done_child.id}"
    assert_select "#entry_#{note.id}"
  end

  test "header traversal stops at a soft-deleted child" do
    requested_date = Date.new(2027, 1, 15)
    root = create_open_task("visible root", logged_on: requested_date)
    deleted_child = create_open_task("deleted child", logged_on: requested_date, parent: root)
    grandchild = create_open_task("hidden grandchild", logged_on: requested_date, parent: deleted_child)
    deleted_child.soft_delete!

    get daily_log_path(date: requested_date.iso8601)

    assert_response :success
    assert_select "[data-testid='open-count']", text: "1 open"
    assert_select "#entry_#{root.id}"
    assert_select "#entry_#{deleted_child.id}", count: 0
    assert_select "#entry_#{grandchild.id}", count: 0
  end
end
