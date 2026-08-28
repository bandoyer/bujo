require "test_helper"

# Verifies page controls independently of JavaScript so hidden affordances and
# resident action strips cannot accidentally grant a different domain command.
class PageRenderingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "application renders one Turbo-tracked Tailwind stylesheet" do
    get daily_log_path(date: Time.zone.today.iso8601)

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='tailwind'][data-turbo-track='reload']", count: 1
    assert_select "link[rel='stylesheet'][href*='application.css']", count: 0
  end

  test "future Daily pages render residents and actions but no capture affordance" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      resident = create_open_task("already carried", page_on: Date.new(2026, 8, 26))

      get daily_log_path(date: "2026-08-26")

      assert_response :success
      assert_select "#entry_#{resident.id}"
      assert_select "#entry_#{resident.id} form[action='#{migrate_entry_path(resident)}']"
      assert_select "#capture_reveal", count: 0
      assert_select "#rapid_log_panel", count: 0
    end
  end

  test "Calendar rows make capture primary and keep a separate Daily chevron" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      day = Date.new(2026, 8, 12)
      event = create_resident(
        "planning session",
        kind: "event",
        page_kind: "monthly_calendar",
        page_on: day.beginning_of_month,
        occurs_on: day
      )

      get monthly_log_path(month: "2026-08")

      assert_response :success
      assert_select "button.monthly-calendar__capture-reveal[aria-controls='calendar_capture_#{day.iso8601}']" do
        assert_select ".monthly-calendar__number", text: day.day.to_s
        assert_select ".monthly-calendar__weekday", text: day.strftime("%a").first.upcase
      end
      assert_select "a.monthly-calendar__daily-link[href='#{daily_log_path(date: day.iso8601)}']",
        text: "›", count: 1
      assert_select "a.monthly-calendar__daily-link[aria-label='Open Daily Log for #{day.strftime('%B %-d, %Y')}']"
      assert_select "[data-page-capture='monthly_calendar'][data-date='#{day.iso8601}']"
      assert_select "#monthly_entry_#{event.id} a[href='#{daily_log_path(date: day.iso8601)}']", count: 0
      assert_select "#monthly_entry_#{event.id} form[action='#{schedule_entry_path(event)}']"
      assert_select ".monthly-calendar__capture-panel [data-kind='note']", count: 31

      get monthly_log_path(month: "2026-09")
      assert_select "button.monthly-calendar__capture-reveal", count: 0
      assert_select "a.monthly-calendar__daily-link", count: 30
    end
  end

  test "Monthly Tasks count and render the resident tree and close future capture" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      month = Date.new(2026, 8, 1)
      root = create_open_task("curated root", page_on: month, page_kind: "monthly_tasks")
      create_open_task("nested task", page_on: month, page_kind: "monthly_tasks", parent: root)

      get monthly_log_path(month: "2026-08", view: "tasks")
      assert_select ".monthly-task-count", text: "2 open · 2 logged"
      assert_select "[data-page-capture='monthly_tasks']"
      assert_select "[data-page-capture='monthly_tasks'] [data-kind='event']", count: 1
      assert_select "[data-page-capture='monthly_tasks'] [data-kind='note']", count: 1
      assert_select "#monthly_task_#{root.id} a[href^='/daily']", count: 0

      get monthly_log_path(month: "2026-09", view: "tasks")
      assert_select "[data-page-capture='monthly_tasks']", count: 0
    end
  end

  test "Future Log shows overdue residents read-only and adds only after current month" do
    travel_to Time.zone.local(2026, 8, 25, 12) do
      overdue = create_resident(
        "still waiting",
        kind: "event",
        page_kind: "future",
        page_on: nil,
        occurs_on: Date.new(2026, 7, 3)
      )
      future = create_resident(
        "later plan",
        kind: "task",
        page_kind: "future",
        page_on: nil,
        occurs_on: Date.new(2026, 9, 5)
      )

      get future_log_path

      assert_select ".future-log__month[data-month='2026-07'] #future_entry_#{overdue.id}"
      assert_select ".future-log__month[data-month='2026-07'] button[id$='_toggle']", count: 0
      assert_select ".future-log__month[data-month='2026-09'] button[id$='_toggle']", count: 2
      assert_select "#future_entry_#{overdue.id} a", count: 0
      assert_select "#future_entry_#{future.id} form[action='#{entry_path(future)}']", count: 1
      assert_select ".future-log__add-row [data-kind='note']", count: 0
      assert_select ".future-log__month[data-month='2026-09'] form.rapid-log" do
        assert_select "button.rapid-log__kind[aria-label='Task'][aria-pressed='true']", text: "•"
        assert_select "button.rapid-log__kind[aria-label='Event'][aria-pressed='false']"
        assert_select "input[name='default_kind'][value='task']"
        assert_select "input[name='placement'][value='future']"
        assert_select "input[name='on'][value='']"
        assert_select "input[aria-label='Day of the month'][required]"
        assert_select "input[placeholder='Rapid log…'][data-rapid-log-target~='line']"
      end
    end
  end

  test "Daily events and notes offer eligible movement commands only before moving" do
    day = Time.zone.today
    event = create_resident("meet", kind: "event", page_kind: "daily", page_on: day)
    note = create_resident("remember", kind: "note", page_kind: "daily", page_on: day)

    get daily_log_path(date: day.iso8601)
    assert_select "#entry_#{event.id} form[action='#{schedule_entry_path(event)}']"
    assert_select "#entry_#{event.id} form[action='#{move_to_collection_entry_path(event)}']"
    assert_select "#entry_#{note.id} form[action='#{move_to_collection_entry_path(note)}']"

    event.move_to!(
      page_kind: "future", page_on: nil, occurs_on: day.next_month.beginning_of_month,
      as_of: day
    )
    get daily_log_path(date: day.iso8601)
    assert_select "#entry_#{event.id} form", count: 0
    assert_select "#entry_#{event.id} .entry__meta", text: /→/
  end

  test "writable empty Daily copy is inside the one real capture button" do
    @user.entries.update_all(deleted_at: Time.current)

    get daily_log_path(date: Time.zone.today.iso8601)

    assert_select "button[aria-label='Write on this page']", count: 1 do
      assert_select ".entry-list__empty", text: "Nothing logged yet.", count: 1
      assert_select "button button", count: 0
    end

    get daily_log_path(date: Time.zone.today.next_day.iso8601)
    assert_select ".entry-list__empty", text: "Nothing logged yet.", count: 1
    assert_select "button[aria-label='Write on this page']", count: 0
  end

  test "all current rows offer Edit except a row with a successor" do
    day = Time.zone.today
    open = create_resident("open", kind: "task", page_kind: "daily", page_on: day)
    future = create_resident(
      "future", kind: "event", page_kind: "future", page_on: nil,
      occurs_on: day.next_month.beginning_of_month
    )
    moved = create_resident("moved", kind: "task", page_kind: "daily", page_on: day)
    moved.move_to!(page_kind: "monthly_tasks", page_on: day.next_month.beginning_of_month, as_of: day)

    get daily_log_path(date: day.iso8601)
    assert_select "#entry_#{open.id} button", text: "Edit"
    assert_select "#entry_#{moved.id} button", text: "Edit", count: 0

    get future_log_path
    assert_select "#entry_#{future.id} button", text: "Edit"
  end

  test "Future Note child editor selects Note without broadening Future capture" do
    root = create_resident(
      "future root", kind: "task", page_kind: "future", page_on: nil,
      occurs_on: Time.zone.today.next_month.beginning_of_month
    )
    child = create_resident(
      "future context", kind: "note", page_kind: "future", page_on: nil,
      occurs_on: nil, parent: root
    )

    get future_log_path

    assert_select "#entry_#{child.id} form[action='#{entry_path(child)}']" do
      assert_select "button[aria-label='Task'][aria-pressed='false']", count: 1
      assert_select "button[aria-label='Event'][aria-pressed='false']", count: 1
      assert_select "button[aria-label='Note'][aria-pressed='true']", count: 1
      assert_select "input[name='default_kind'][value='note']", count: 1
    end
    assert_select ".future-log__add-row button[aria-label='Note']", count: 0
  end

  test "entry refusal alerts follow titles on every resident page" do
    month = Time.zone.today.beginning_of_month
    collection = Collection.create_for(user: @user, topic: "Refusal Topic")
    cases = [
      [ create_open_task("daily refusal", page_on: Time.zone.today), daily_log_path(date: Time.zone.today.iso8601) ],
      [ create_resident("calendar refusal", kind: "event", page_kind: "monthly_calendar",
          page_on: month, occurs_on: Time.zone.today), monthly_log_path(month: month.strftime("%Y-%m")) ],
      [ create_open_task("tasks refusal", page_on: month, page_kind: "monthly_tasks"),
        monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks") ],
      [ create_resident("future refusal", kind: "event", page_kind: "future", page_on: nil,
          occurs_on: month.next_month), future_log_path ],
      [ create_resident("collection refusal", kind: "note", page_kind: "collection", page_on: nil,
          collection: collection), collection_path(collection) ]
    ]

    cases.each do |entry, expected_path|
      patch entry_path(entry), params: { line: "", default_kind: entry.kind }
      assert_redirected_to expected_path
      follow_redirect!
      assert_response :success
      assert_operator response.body.index("<h1"), :<, response.body.index("role=\"alert\"")
      assert_select "[role='alert']", text: "That entry can't do that."
      assert_select "#entry_#{entry.id} input[name='line'][value='']", count: 1
    end
  end

  private

  def create_resident(text, kind:, **placement)
    @user.entries.create!(
      { kind: kind, state: ("open" if kind == "task"), text: text, tags: [] }.merge(placement)
    )
  end
end
