require "test_helper"

class DailyLogAuthenticationTest < ActionDispatch::IntegrationTest
  test "every daily log route requires authentication" do
    task = entries(:open_task)
    today = Time.zone.today.iso8601
    protected_requests = [
      -> { get root_path },
      -> { get daily_log_path(date: today) },
      -> { post entries_path, params: { line: "private" } },
      -> { post complete_entry_path(task) },
      -> { post reopen_entry_path(task) },
      -> { post strike_entry_path(task) },
      -> { post migrate_entry_path(task), params: { viewed_on: today } },
      -> { post schedule_entry_path(task), params: { date: today } },
      -> { patch theme_path, params: { theme: "dark" } },
      -> { patch lettering_path, params: { hand: "rock-salt" } }
    ]

    protected_requests.each do |request|
      request.call
      assert_redirected_to new_session_path
    end
  end
end
