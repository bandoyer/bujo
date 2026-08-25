require "test_helper"

# Pins the server-side guards behind page controls that may be hidden in the
# browser. Crafted requests must use the same refusal path as visible forms.
class PageCaptureControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "future Daily capture is refused while past capture remains admitted" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      assert_capture_refused(on: "2026-08-26")

      assert_difference -> { @user.entries.daily_log(Date.new(2026, 8, 24)).count }, 1 do
        post entries_path, params: { line: "past resident", on: "2026-08-24" }
      end
    end
  end

  test "Calendar capture accepts task and event residents but refuses a note" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      day = Date.new(2026, 8, 12)
      capture_page("calendar task tomorrow", day, placement: "monthly_calendar")
      assert_redirected_to monthly_log_path(month: "2026-08")
      capture_page("calendar event", day, placement: "monthly_calendar", default_kind: "event")
      assert_redirected_to monthly_log_path(month: "2026-08")
      assert_capture_refused(
        on: day.iso8601,
        placement: "monthly_calendar",
        default_kind: "note"
      )

      residents = @user.entries.monthly_calendar(day)
      assert_equal %w[task event], residents.order(:created_at, :id).pluck(:kind)
      assert_equal [ day, day ], residents.pluck(:occurs_on)
      assert_empty @user.entries.daily_log(day)
      assert_empty @user.entries.monthly_tasks(day)
    end
  end

  test "Monthly Tasks capture accepts only task roots and closes future months" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      month = Date.new(2026, 8, 1)
      capture_page("monthly task", month, placement: "monthly_tasks")
      assert_redirected_to monthly_log_path(month: "2026-08", view: "tasks")
      capture_page("inventory tomorrow", month, placement: "monthly_tasks")
      assert_equal Date.new(2026, 8, 26), @user.entries.find_by!(text: "inventory").occurs_on
      assert_capture_refused(on: month.iso8601, placement: "monthly_tasks", default_kind: "event")
      assert_capture_refused(on: month.next_month.iso8601, placement: "monthly_tasks")

      assert_equal [ "monthly task", "inventory" ], @user.entries.monthly_tasks(month).pluck(:text)
    end
  end

  test "Future capture begins after the current month and remains NULL-page residency" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      assert_capture_refused(on: "2026-08-31", placement: "future")
      assert_capture_refused(on: "2026-09-01", placement: "future", default_kind: "note")

      capture_page("future event", Date.new(2026, 9, 1), placement: "future", default_kind: "event")
      resident = @user.entries.find_by!(text: "future event")
      assert_equal [ "future", nil, Date.new(2026, 9, 1) ],
        [ resident.page_kind, resident.page_on, resident.occurs_on ]
    end
  end

  test "Migrate derives next Tasks page from entry residency not return parameters" do
    task = create_open_task("carry me", page_on: Date.new(2026, 8, 12))

    post migrate_entry_path(task), params: {
      viewed_on: "2035-11-20",
      return_to: "monthly_tasks"
    }

    successor = task.reload.successor
    assert_equal [ "monthly_tasks", Date.new(2026, 9, 1) ],
      [ successor.page_kind, successor.page_on ]
    assert_redirected_to monthly_log_path(month: "2035-11", view: "tasks")
  end

  test "Schedule admits an event once and rejects a same-month destination" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      event = @user.entries.create!(
        kind: "event", state: nil, text: "conference", tags: [],
        page_kind: "daily", page_on: Date.new(2026, 8, 25)
      )

      post schedule_entry_path(event), params: { viewed_on: "2026-08-25", date: "2026-08-31" }
      assert_equal "That entry can't do that.", flash[:alert]
      assert_nil event.reload.successor

      post schedule_entry_path(event), params: { viewed_on: "2026-08-25", date: "2026-09-05" }
      assert_equal [ "future", Date.new(2026, 9, 5) ],
        [ event.reload.successor.page_kind, event.successor.occurs_on ]

      assert_no_difference -> { @user.entries.count } do
        post schedule_entry_path(event), params: { viewed_on: "2026-08-25", date: "2026-10-01" }
      end
      assert_equal "That entry can't do that.", flash[:alert]
    end
  end

  test "crafted Migrate against a Future resident uses the refusal path" do
    future_task = @user.entries.create!(
      kind: "task", state: "open", text: "waiting in Future", tags: [],
      page_kind: "future", page_on: nil, occurs_on: Time.zone.today.next_month.beginning_of_month
    )

    assert_no_difference -> { @user.entries.count } do
      post migrate_entry_path(future_task), params: { viewed_on: Time.zone.today.iso8601 }
    end

    assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
    assert_nil future_task.reload.successor
  end

  test "crafted Schedule refuses notes and Future residents" do
    note = @user.entries.create!(
      kind: "note", state: nil, text: "daily context", tags: [],
      page_kind: "daily", page_on: Time.zone.today
    )
    future_event = @user.entries.create!(
      kind: "event", state: nil, text: "already waiting", tags: [],
      page_kind: "future", page_on: nil, occurs_on: Time.zone.today.next_month.beginning_of_month
    )

    [ note, future_event ].each do |entry|
      assert_no_difference -> { @user.entries.count } do
        post schedule_entry_path(entry), params: {
          viewed_on: Time.zone.today.iso8601,
          date: Time.zone.today.next_month.beginning_of_month.iso8601
        }
      end
      assert_equal "That entry can't do that.", flash[:alert]
      assert_nil entry.reload.successor
    end
  end

  test "task lifecycle commands refuse Future and Collection residents without changes" do
    [ future_placement, collection_placement ].each do |placement|
      %i[complete strike reopen].each do |command|
        task = create_lifecycle_task(command, **placement)
        original_attributes = task.attributes

        assert_no_difference -> { @user.entries.count } do
          post lifecycle_path(command, task), params: { viewed_on: Time.zone.today.iso8601 }
        end

        assert_redirected_to daily_log_path(date: Time.zone.today.iso8601)
        assert_equal "That entry can't do that.", flash[:alert]
        assert_equal original_attributes, task.reload.attributes
        assert_nil task.successor
      end
    end
  end

  test "task lifecycle commands remain admitted on every actionable page" do
    actionable_placements.each do |placement|
      { complete: "done", strike: "struck", reopen: "open" }.each do |command, expected_state|
        task = create_lifecycle_task(command, **placement)

        assert_no_difference -> { @user.entries.count } do
          post lifecycle_path(command, task), params: { viewed_on: Time.zone.today.iso8601 }
        end

        assert_nil flash[:alert]
        assert_equal expected_state, task.reload.state
        assert_nil task.successor
      end
    end
  end

  # The command list comes from the routes rather than a literal, so a member
  # command added without the residency guard fails here instead of shipping
  # reachable from every page. Schedule is posted with a legal Future date so
  # a missing-date refusal cannot masquerade as the residency guard.
  test "every entry member command refuses a resident of a page without controls" do
    commands = member_entry_commands
    assert_equal %w[complete reopen strike migrate schedule].sort, commands.sort
    schedule_on = Time.zone.today.next_month.beginning_of_month.iso8601

    [ future_placement, collection_placement ].each do |placement|
      commands.each do |command|
        task = create_lifecycle_task(:complete, **placement)
        original_attributes = task.attributes
        params = { viewed_on: Time.zone.today.iso8601 }
        params[:date] = schedule_on if command == "schedule"

        assert_no_difference -> { @user.entries.count } do
          post lifecycle_path(command, task), params: params
        end

        assert_equal "That entry can't do that.", flash[:alert],
          "#{command} was not refused on #{placement.fetch(:page_kind)}"
        assert_equal original_attributes, task.reload.attributes
        assert_nil task.successor
      end
    end
  end

  private

  # Every non-create action the entries routes expose on a single entry.
  def member_entry_commands
    Rails.application.routes.routes.filter_map do |route|
      action = route.defaults[:action]
      action if route.defaults[:controller] == "entries" && action != "create"
    end.uniq
  end

  def future_placement
    {
      page_kind: "future", page_on: nil,
      occurs_on: Time.zone.today.next_month.beginning_of_month
    }
  end

  def collection_placement
    { page_kind: "collection", page_on: nil, collection: collections(:camping) }
  end

  def actionable_placements
    month = Time.zone.today.beginning_of_month
    [
      { page_kind: "daily", page_on: Time.zone.today },
      { page_kind: "monthly_calendar", page_on: month, occurs_on: Time.zone.today },
      { page_kind: "monthly_tasks", page_on: month }
    ]
  end

  def create_lifecycle_task(command, **placement)
    @user.entries.create!(
      kind: "task",
      state: command == :reopen ? "done" : "open",
      text: "#{placement.fetch(:page_kind)} #{command}",
      tags: [],
      **placement
    )
  end

  def lifecycle_path(command, task)
    public_send("#{command}_entry_path", task)
  end

  def capture_page(line, on, **placement)
    post entries_path, params: { line: line, on: on.iso8601, **placement }
    assert_response :redirect
  end

  def assert_capture_refused(**params)
    assert_no_difference -> { @user.entries.count } do
      post entries_path(format: :turbo_stream), params: { line: "refused", **params }
    end
    assert_response :unprocessable_entity
    assert_equal "That entry can't do that.", flash[:alert]
  end
end
