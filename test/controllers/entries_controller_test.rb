require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "blank capture is a successful no-op" do
    assert_no_difference -> { @user.entries.count } do
      post entries_path(format: :turbo_stream), params: { line: "   " }
    end

    assert_response :success
  end

  test "absent and unrecognized default kinds capture tasks" do
    assert_difference -> { @user.entries.where(kind: "task").count }, 2 do
      post entries_path(format: :turbo_stream), params: { line: "first fallback" }
      assert_response :success

      post entries_path(format: :turbo_stream), params: {
        line: "second fallback",
        default_kind: "bogus"
      }
      assert_response :success
    end

    assert_equal %w[first\ fallback second\ fallback],
      @user.entries.where(text: [ "first fallback", "second fallback" ]).order(:created_at, :id).pluck(:text)
  end

  test "recognized default kind captures that kind" do
    assert_difference -> { @user.entries.where(kind: "event").count }, 1 do
      post entries_path(format: :turbo_stream), params: {
        line: "standup 9am",
        default_kind: "event"
      }
    end

    assert_response :success
  end

  test "an illegal lifecycle action redirects with an alert" do
    task = create_open_task("finish twice", logged_on: Time.zone.today)

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
  end

  test "schedule rejects an absent date without moving the task" do
    assert_schedule_rejected
  end

  test "schedule rejects an unparseable date without moving the task" do
    assert_schedule_rejected(date: "not-a-date")
  end

  test "schedule with an ISO date moves the task" do
    viewed_on = Date.new(2027, 1, 15)
    occurs_on = Date.new(2027, 2, 1)
    task = create_open_task("pack", logged_on: viewed_on)

    post schedule_entry_path(task), params: {
      viewed_on: viewed_on.iso8601,
      date: occurs_on.iso8601
    }

    assert_redirected_to daily_log_path(date: viewed_on.iso8601)
    assert_nil flash[:alert]
    task.reload
    assert_equal "migrated", task.state
    assert_equal occurs_on, task.successor.occurs_on
  end

  private

  def assert_schedule_rejected(schedule_params = {})
    viewed_on = Date.new(2027, 1, 15)
    task = create_open_task("stay put", logged_on: viewed_on)
    original_lifecycle = [ task.state, task.occurs_on ]

    post schedule_entry_path(task), params: { viewed_on: viewed_on.iso8601 }.merge(schedule_params)

    assert_redirected_to daily_log_path(date: viewed_on.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
    task.reload
    assert_equal original_lifecycle, [ task.state, task.occurs_on ]
  end
end
