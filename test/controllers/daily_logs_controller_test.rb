require "test_helper"

class DailyLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
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
end
