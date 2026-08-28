require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "blank capture is a successful no-op" do
    assert_no_difference -> { @user.entries.count } do
      post entries_path(format: :turbo_stream), params: {
        line: "   ",
        on: (Time.zone.today.prev_month.beginning_of_month + 14.days).iso8601
      }
    end

    assert_response :success
  end

  test "absent and unrecognized default kinds capture tasks" do
    capture_date = Time.zone.today.prev_month.beginning_of_month + 14.days

    assert_difference -> { @user.entries.where(kind: "task").count }, 2 do
      post entries_path(format: :turbo_stream), params: {
        line: "first fallback",
        on: capture_date.iso8601
      }
      assert_response :success

      post entries_path(format: :turbo_stream), params: {
        line: "second fallback",
        default_kind: "bogus",
        on: capture_date.iso8601
      }
      assert_response :success
    end

    assert_equal %w[first\ fallback second\ fallback],
      @user.entries.where(text: [ "first fallback", "second fallback" ]).order(:created_at, :id).pluck(:text)
  end

  test "recognized default kind captures that kind" do
    capture_date = Time.zone.today.prev_month.beginning_of_month + 14.days

    assert_difference -> { @user.entries.where(kind: "event").count }, 1 do
      post entries_path(format: :turbo_stream), params: {
        line: "standup 9am",
        default_kind: "event",
        on: capture_date.iso8601
      }
    end

    assert_response :success
  end

  test "capture uses the requested page date for logging and relative parsing" do
    capture_date = Time.zone.today.prev_month.beginning_of_month + 14.days

    assert_difference -> { @user.entries.count }, 1 do
      post entries_path(format: :turbo_stream), params: {
        line: "prepare tomorrow",
        on: capture_date.iso8601
      }
    end

    assert_response :success
    captured = @user.entries.find_by!(text: "prepare")
    assert_equal capture_date, captured.page_on
    assert_equal capture_date.next_day, captured.occurs_on
  end

  test "capture refuses an absent page date without falling back to today" do
    assert_capture_date_refused(nil)
  end

  test "capture refuses an unparseable page date without falling back to today" do
    assert_capture_date_refused("not-a-date")
  end

  test "future placement logs and occurs on the requested day" do
    capture_date = Time.zone.today.next_month.beginning_of_month + 4.days

    assert_difference -> { @user.entries.count }, 1 do
      post entries_path(format: :turbo_stream), params: {
        line: "future appointment",
        on: capture_date.iso8601,
        placement: "future"
      }
    end

    assert_response :success
    captured = @user.entries.find_by!(text: "future appointment")
    assert_nil captured.page_on
    assert_equal capture_date, captured.occurs_on
  end

  test "future placement refuses a nonfuture date that Daily placement accepts" do
    past_date = Time.zone.today.prev_day

    [ past_date, Time.zone.today ].each do |nonfuture_date|
      assert_no_difference -> { @user.entries.count } do
        post entries_path(format: :turbo_stream), params: {
          line: "must stay visible",
          on: nonfuture_date.iso8601,
          placement: "future"
        }
      end
      assert_response :unprocessable_entity
      assert_equal "That entry can't do that.", flash[:alert]
    end

    assert_difference -> { @user.entries.count }, 1 do
      post entries_path(format: :turbo_stream), params: {
        line: "past page capture",
        on: past_date.iso8601
      }
    end
    assert_response :success
    assert_equal past_date, @user.entries.find_by!(text: "past page capture").page_on
  end

  test "HTML capture returns to the requested page date" do
    capture_date = Time.zone.today.prev_month.beginning_of_month + 7.days

    post entries_path, params: { line: "fallback capture", on: capture_date.iso8601 }

    assert_redirected_to daily_log_path(date: capture_date.iso8601)
    assert_equal capture_date, @user.entries.find_by!(text: "fallback capture").page_on
  end

  test "HTML future capture returns to the Future Log" do
    capture_date = Time.zone.today.next_month.beginning_of_month + 7.days

    post entries_path, params: {
      line: "fallback future",
      on: capture_date.iso8601,
      placement: "future"
    }

    assert_redirected_to future_log_path
    captured = @user.entries.find_by!(text: "fallback future")
    assert_nil captured.page_on
    assert_equal capture_date, captured.occurs_on
  end

  test "Reflection capture ignores authored placement and date and returns to its originating mode" do
    today = Date.new(2026, 8, 27)

    travel_to today do
      [ [ "reflection_morning", reflection_path ], [ "reflection_evening", evening_reflection_path ] ].each do |return_to, path|
        assert_difference -> { @user.entries.daily_log(today).count }, 1 do
          post entries_path, params: {
            line: "captured from #{return_to}",
            default_kind: "note",
            return_to: return_to,
            placement: "future",
            on: today.next_month.iso8601,
            page_kind: "collection"
          }
        end
        assert_redirected_to path
        assert_equal "capture", flash[:reflection_focus]
        captured = @user.entries.find_by!(text: "captured from #{return_to}")
        assert_equal [ "note", nil, "daily", today, nil, nil ],
          captured.values_at(:kind, :state, :page_kind, :page_on, :collection_id, :migrated_from_id)
      end
    end
  end

  test "Reflection capture refusal preserves the line and selected kind in its originating mode" do
    travel_to Date.new(2026, 8, 27) do
      assert_no_difference -> { @user.entries.count } do
        post entries_path, params: {
          line: "-",
          default_kind: "event",
          return_to: "reflection_evening",
          placement: "future"
        }
      end

      assert_redirected_to evening_reflection_path
      assert_equal "-", flash[:reflection_line]
      assert_equal "event", flash[:reflection_kind]
      assert_equal "capture", flash[:reflection_focus]
      follow_redirect!
      assert_select "input#reflection_line[value='-']"
      assert_select "button[aria-label='Event'][aria-pressed='true']"
      assert_select ".flash--alert", text: "That entry can't do that."
    end
  end

  test "Evening lifecycle actions return safely and retain existing authorization" do
    today = Date.new(2026, 8, 27)

    travel_to today do
      complete = create_open_task("evening complete", page_on: today)
      post complete_entry_path(complete), params: { return_to: "reflection_evening", viewed_on: today.iso8601 }
      assert_redirected_to evening_reflection_path
      assert_equal "entry:#{complete.id}", flash[:reflection_focus]
      assert_equal "done", complete.reload.state

      struck = create_open_task("evening strike", page_on: today)
      post strike_entry_path(struck), params: { return_to: "reflection_evening", viewed_on: today.iso8601 }
      assert_redirected_to evening_reflection_path
      assert_equal "entry:#{struck.id}", flash[:reflection_focus]
      assert_equal "struck", struck.reload.state

      scheduled = create_open_task("evening schedule", page_on: today)
      post schedule_entry_path(scheduled), params: {
        return_to: "reflection_evening", viewed_on: today.iso8601, date: (today + 2.days).iso8601
      }
      assert_redirected_to evening_reflection_path
      assert_equal "entry:#{scheduled.id}", flash[:reflection_focus]
      assert_equal [ "monthly_calendar", today.beginning_of_month, today + 2.days ],
        scheduled.reload.successor.values_at(:page_kind, :page_on, :occurs_on)

      future = create_open_task("evening future", page_on: today)
      post schedule_entry_path(future), params: {
        return_to: "reflection_evening", viewed_on: today.iso8601, date: today.next_month.iso8601
      }
      assert_redirected_to evening_reflection_path
      assert_equal [ "future", nil, today.next_month ],
        future.reload.successor.values_at(:page_kind, :page_on, :occurs_on)
    end
  end

  test "crafted return values never redirect lifecycle or capture to an arbitrary URL" do
    today = Time.zone.today
    task = create_open_task("safe return", page_on: today)

    post complete_entry_path(task), params: { return_to: "https://attacker.example", viewed_on: today.iso8601 }
    assert_redirected_to daily_log_path(date: today.iso8601)

    post complete_entry_path(create_open_task("prefix return", page_on: today)), params: {
      return_to: "reflection_tomorrow", viewed_on: today.iso8601
    }
    assert_redirected_to daily_log_path(date: today.iso8601)

    post entries_path, params: {
      line: "safe capture", on: today.iso8601, return_to: "//attacker.example"
    }
    assert_redirected_to daily_log_path(date: today.iso8601)

    post entries_path, params: {
      line: "prefix capture", on: today.iso8601, return_to: "reflection_tomorrow"
    }
    assert_redirected_to daily_log_path(date: today.iso8601)
  end

  test "turbo capture refusal stays on the submitting request" do
    assert_no_difference -> { @user.entries.count } do
      post entries_path(format: :turbo_stream), params: {
        line: "must not land",
        on: "not-a-date"
      }
    end

    assert_response :unprocessable_entity
    assert_equal "That entry can't do that.", flash[:alert]
  end

  test "an illegal lifecycle action redirects with an alert" do
    task = create_open_task("finish twice", page_on: Time.zone.today)

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)

    post complete_entry_path(task), params: { viewed_on: Time.zone.today.iso8601 }
    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
  end

  test "strike and reopen change task state and return to the viewed page" do
    viewed_on = Time.zone.today
    task = create_open_task("cycle me", page_on: viewed_on)

    post strike_entry_path(task), params: { viewed_on: viewed_on.iso8601 }
    assert_redirected_to daily_log_path(date: viewed_on.iso8601)
    assert_equal "struck", task.reload.state

    post reopen_entry_path(task), params: { viewed_on: viewed_on.iso8601 }
    assert_redirected_to daily_log_path(date: viewed_on.iso8601)
    assert_equal "open", task.reload.state
  end

  test "schedule rejects an absent date without moving the task" do
    assert_schedule_rejected
  end

  test "schedule rejects an unparseable date without moving the task" do
    assert_schedule_rejected(date: "not-a-date")
  end

  test "schedule with an ISO date moves the task" do
    viewed_on = Time.zone.today.prev_month.beginning_of_month + 14.days
    occurs_on = Time.zone.today.next_month.beginning_of_month
    task = create_open_task("pack", page_on: viewed_on)

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

  def assert_capture_date_refused(on)
    params = { line: "must not land today" }
    params[:on] = on unless on.nil?

    assert_no_difference -> { @user.entries.count } do
      post entries_path, params: params, headers: { "HTTP_REFERER" => future_log_url }
    end

    assert_redirected_to future_log_path
    assert_equal "That entry can't do that.", flash[:alert]
    assert_nil @user.entries.find_by(text: "must not land today", page_on: Time.zone.today)
  end

  def assert_schedule_rejected(schedule_params = {})
    viewed_on = Time.zone.today.prev_month.beginning_of_month + 14.days
    task = create_open_task("stay put", page_on: viewed_on)
    original_lifecycle = [ task.state, task.occurs_on ]

    post schedule_entry_path(task), params: { viewed_on: viewed_on.iso8601 }.merge(schedule_params)

    assert_redirected_to daily_log_path(date: viewed_on.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
    task.reload
    assert_equal original_lifecycle, [ task.state, task.occurs_on ]
  end
end
