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
    task = @user.entries.create!(
      kind: "task",
      state: "open",
      text: "finish twice",
      tags: [],
      logged_on: Time.zone.today
    )

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
  end
end
