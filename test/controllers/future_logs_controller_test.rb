require "test_helper"

class FutureLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "runway starts from the first occupied future month and includes later occupied months" do
    travel_to Time.zone.local(2027, 1, 15, 12) do
      today = Time.zone.today
      current_entry = create_event("later this month", occurs_on: today + 5.days)
      create_event("next month", occurs_on: today.next_month.beginning_of_month + 2.days)
      far_month = today.beginning_of_month >> 8
      create_event("far runway", occurs_on: far_month + 1.day)

      get future_log_path
      assert_response :success
      assert_equal runway_months(today.beginning_of_month, far_month), rendered_months

      current_entry.soft_delete!
      get future_log_path
      assert_response :success
      assert_equal runway_months(today.next_month.beginning_of_month, far_month), rendered_months
    end
  end

  test "future glyphs follow the active hand" do
    future_date = Time.zone.today.next_month.beginning_of_month + 3.days
    event = create_event("future circle", occurs_on: future_date)

    get future_log_path
    assert_select "#future_entry_#{event.id} .entry__glyph", text: "O"

    patch lettering_path, params: { hand: "sans" }
    get future_log_path
    assert_select "#future_entry_#{event.id} .entry__glyph", text: "○"
  end

  test "an empty future keeps six faint headers without empty-state copy" do
    get future_log_path

    assert_response :success
    assert_select ".future-log__month", count: 6
    assert_select ".future-log__month.future-log__month--empty", count: 6
    assert_select ".future-entry", count: 0
    assert_select ".entry-list__empty", count: 0
  end

  private

  def create_event(text, occurs_on:)
    @user.entries.create!(
      kind: "event",
      state: nil,
      text: text,
      tags: [],
      logged_on: Time.zone.today,
      occurs_on: occurs_on
    )
  end

  def runway_months(first_month, far_month)
    months = 6.times.map { |offset| first_month >> offset }
    months << far_month unless months.include?(far_month)
    months.map { |month| month.strftime("%Y-%m") }
  end

  def rendered_months
    css_select(".future-log__month").map { |node| node["data-month"] }
  end
end
