require "test_helper"

# Exercises the derived Monthly Migration queue and every server-authorized
# resolution without relying on browser-hidden controls for authorization.
class MonthlyMigrationsControllerTest < ActionDispatch::IntegrationTest
  AS_OF = Date.new(2026, 8, 26)
  TARGET_MONTH = Date.new(2026, 9, 1)
  SOURCE_MONTH = Date.new(2026, 8, 1)

  setup do
    @user = users(:one)
    @other_user = users(:two)
    @user.entries.update_all(deleted_at: Time.current)
    @other_user.entries.update_all(deleted_at: Time.current)
    sign_in_as @user
  end

  test "every ritual route requires authentication before it can read or write" do
    candidate = create_entry(text: "authentication guard", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    sign_out
    original = journal_snapshot
    routes = [
      [ :get, migration_path ],
      [ :post, migration_inventory_path ],
      [ :get, migration_outgoing_path ],
      [ :post, migration_outgoing_strike_path(candidate) ],
      [ :post, migration_outgoing_tasks_path(candidate) ],
      [ :post, migration_outgoing_collection_path(candidate) ],
      [ :post, migration_outgoing_future_path(candidate) ],
      [ :get, migration_future_path ],
      [ :post, migration_future_strike_path(candidate) ],
      [ :post, migration_future_tasks_path(candidate) ],
      [ :post, migration_future_calendar_path(candidate) ],
      [ :get, migration_complete_path ]
    ]

    routes.each do |verb, path|
      public_send(verb, path)
      assert_redirected_to new_session_path
      assert_equal original, journal_snapshot
    end
  end

  test "setup admits past current and next targets but uniformly hides malformed and distant targets" do
    travel_to AS_OF do
      [ AS_OF.prev_month, AS_OF.beginning_of_month, TARGET_MONTH ].each do |month|
        get migration_path(month)

        assert_response :success
        assert_title_first
        assert_select ".monthly-migration__context", text: /#{month.prev_month.strftime('%B')}.*#{month.strftime('%B %Y')}/
        assert_select ".tab-bar__item--active[aria-current='page']", text: "Month"
      end

      [ "not-a-month", "2026-13", "2026-09junk", "2026-10" ].each do |month|
        get migration_path(month)

        assert_response :not_found
        assert_select "h1", text: "Monthly Migration not found", count: 1
        assert_select ".tab-bar__item--active[aria-current='page']", text: "Month"
        assert_no_match(/Fixture task|Other User/, response.body)
      end
    end
  end

  test "setup renders target Tasks trees and captures only valid task inventory" do
    existing = create_entry(text: "existing target root", page_kind: "monthly_tasks", page_on: TARGET_MONTH)
    create_entry(text: "nested target context", page_kind: "monthly_tasks", page_on: TARGET_MONTH, parent: existing)
    create_entry(user: @other_user, text: "foreign target words", page_kind: "monthly_tasks", page_on: TARGET_MONTH)

    travel_to AS_OF do
      get migration_path

      assert_response :success
      assert_select "h1", text: "Monthly Migration", count: 1
      assert_select ".monthly-migration__stage", text: "Fresh mental inventory"
      assert_select "#entry_#{existing.id}"
      assert_select ".entry__text", text: "nested target context"
      assert_no_match(/foreign target words/, response.body)
      assert_select "label[for='monthly_migration_line']", text: "What matters this month?"
      assert_select "form[action='#{migration_inventory_path}'] input[type='submit'][value='Log task']"

      assert_difference -> { @user.entries.monthly_tasks(TARGET_MONTH).count }, 1 do
        post migration_inventory_path, params: { line: "* book campground +camping" }
      end
      assert_redirected_to migration_path
      captured = @user.entries.find_by!(text: "book campground")
      assert_equal [ "task", "open", true, %w[camping], "monthly_tasks", TARGET_MONTH, nil, nil ],
        captured.values_at(:kind, :state, :priority, :tags, :page_kind, :page_on, :occurs_on, :time_of_day)
      assert_uuid_v7 captured.id
      assert_nil captured.hlc
      assert_nil captured.server_seq

      assert_no_difference -> { Entry.unscoped.count } do
        post migration_inventory_path, params: { line: "" }
      end
      assert_redirected_to migration_path

      [ "- a note", "o an event" ].each do |line|
        assert_no_difference -> { Entry.unscoped.count } do
          post migration_inventory_path, params: { line: line }
        end
        assert_response :unprocessable_entity
        assert_select "input#monthly_migration_line[value='#{line}']"
        assert_select ".flash--alert", text: "That entry can't do that."
      end
    end
  end

  test "outgoing review follows page and depth-first tree order with full kept context" do
    calendar_root = create_entry(
      id: uuid(1), text: "calendar event context", kind: "event", state: nil,
      page_kind: "monthly_calendar", page_on: SOURCE_MONTH, occurs_on: SOURCE_MONTH + 2.days,
      created_at: timestamp
    )
    first = create_entry(
      id: uuid(2), text: "nested calendar task", page_kind: "monthly_calendar",
      page_on: SOURCE_MONTH, occurs_on: SOURCE_MONTH + 2.days, parent: calendar_root, created_at: timestamp
    )
    create_entry(
      id: uuid(3), text: "calendar sibling context", kind: "note", state: nil,
      page_kind: "monthly_calendar", page_on: SOURCE_MONTH, occurs_on: SOURCE_MONTH + 2.days,
      parent: calendar_root, created_at: timestamp
    )
    monthly = create_entry(
      id: uuid(4), text: "monthly task second", page_kind: "monthly_tasks",
      page_on: SOURCE_MONTH, created_at: timestamp
    )
    daily = create_entry(
      id: uuid(5), text: "daily task third", page_kind: "daily",
      page_on: SOURCE_MONTH + 14.days, created_at: timestamp
    )
    create_outgoing_exclusions

    get migration_outgoing_path

    assert_response :success
    assert_select ".monthly-migration__source", text: "Monthly Calendar · August 2026"
    assert_select "#entry_#{calendar_root.id}"
    assert_select "#entry_#{first.id}[aria-label='Review this task']"
    assert_select ".entry__text", text: "calendar sibling context"
    assert_select "#entry_#{first.id} > .monthly-migration__actions form", count: 4
    assert_select "#entry_#{calendar_root.id} > .monthly-migration__actions", count: 0
    assert_select "#entry_#{monthly.id}", count: 0

    [ first, monthly, daily ].each do |candidate|
      post migration_outgoing_strike_path(candidate)
      assert_redirected_to migration_outgoing_path
      assert_equal "struck", candidate.reload.state
      follow_redirect!
      next if candidate == daily

      expected = candidate == first ? monthly : daily
      assert_select "#entry_#{expected.id}[aria-label='Review this task']"
    end
    assert_select ".monthly-migration__stage", text: "Review outgoing tasks"
    assert_select ".monthly-migration__checkpoint p", text: "No unresolved outgoing tasks."
    assert_select "a[href='#{migration_future_path}']", text: "Scan the Future Log"
  end

  test "each outgoing movement rewrites only the selected row with exact destination semantics" do
    destination = @user.collections.create!(name: "Camping Plans")
    parent = create_entry(
      text: "parent context", kind: "note", state: nil,
      page_kind: "daily", page_on: SOURCE_MONTH + 4.days
    )
    to_tasks = create_entry(
      text: "carry dated task", page_kind: "daily", page_on: SOURCE_MONTH + 4.days,
      parent: parent, occurs_on: SOURCE_MONTH + 9.days, time_of_day: "17:30", priority: true, tags: %w[camp]
    )
    child = create_entry(
      text: "child stays behind", kind: "note", state: nil, page_kind: "daily",
      page_on: SOURCE_MONTH + 4.days, parent: to_tasks
    )

    post migration_outgoing_tasks_path(to_tasks)

    assert_redirected_to migration_outgoing_path
    successor = to_tasks.reload.successor
    assert_equal [ "migrated", ">" ], [ to_tasks.state, to_tasks.glyph ]
    assert_equal [ "task", "open", "carry dated task", true, %w[camp], "monthly_tasks", TARGET_MONTH, nil, nil, nil ],
      successor.values_at(:kind, :state, :text, :priority, :tags, :page_kind, :page_on, :occurs_on, :time_of_day, :parent_id)
    assert_equal [ parent.id, to_tasks.id ], [ to_tasks.parent_id, child.reload.parent_id ]
    assert_nil successor.hlc
    assert_nil successor.server_seq

    to_collection = create_entry(text: "move exact topic", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    post migration_outgoing_collection_path(to_collection), params: { topic: "  CAMPING PLANS  ", collection_id: 999 }
    assert_equal destination, to_collection.reload.successor.collection
    assert_nil destination.reload.index_position
    assert_nil to_collection.successor.occurs_on

    to_future = create_entry(
      text: "schedule after target", page_kind: "daily", page_on: SOURCE_MONTH + 8.days,
      time_of_day: "09:15"
    )
    original = journal_snapshot
    post migration_outgoing_future_path(to_future), params: { date: TARGET_MONTH.end_of_month.iso8601 }
    assert_redirected_to migration_outgoing_path
    assert_equal "That entry can't do that.", flash[:alert]
    assert_equal original, journal_snapshot

    post migration_outgoing_future_path(to_future), params: { date: TARGET_MONTH.next_month.iso8601, page_kind: "collection" }
    assert_equal [ "future", nil, TARGET_MONTH.next_month, "09:15" ],
      to_future.reload.successor.values_at(:page_kind, :page_on, :occurs_on, :time_of_day)
    assert_equal "<", to_future.glyph
  end

  test "outgoing authorization refuses wrong stage state destination and stale candidates without side effects" do
    first = create_entry(text: "first candidate", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    second = create_entry(text: "second candidate", page_kind: "daily", page_on: SOURCE_MONTH + 2.days)
    collection = @user.collections.create!(name: "Known Topic")
    foreign = @other_user.collections.create!(name: "Foreign Topic")
    deleted = @user.collections.create!(name: "Deleted Topic")
    deleted.soft_delete_if_unused!

    [
      [ migration_outgoing_tasks_path(second), {} ],
      [ migration_outgoing_collection_path(first), { topic: "" } ],
      [ migration_outgoing_collection_path(first), { topic: foreign.name } ],
      [ migration_outgoing_collection_path(first), { topic: deleted.name } ],
      [ migration_outgoing_future_path(first), { date: "not-a-date" } ]
    ].each do |path, params|
      original = journal_snapshot
      post path, params: params
      assert_redirected_to migration_outgoing_path
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original, journal_snapshot
    end

    first.complete!
    original = journal_snapshot
    post migration_outgoing_collection_path(first), params: { topic: collection.name }
    assert_redirected_to migration_outgoing_path
    assert_equal "That entry can't do that.", flash[:alert]
    assert_equal original, journal_snapshot
  end

  test "Future scan is exact-month ordered and enforces the task event command split" do
    timed_task = create_entry(
      text: "due timed task", page_kind: "future", page_on: nil,
      occurs_on: TARGET_MONTH + 3.days, time_of_day: "08:30"
    )
    untimed_event = create_entry(
      text: "due event", kind: "event", state: nil, page_kind: "future", page_on: nil,
      occurs_on: TARGET_MONTH + 3.days
    )
    create_future_exclusions

    get migration_future_path

    assert_response :success
    assert_select ".monthly-migration__stage", text: "Scan the Future Log"
    assert_select "#entry_#{timed_task.id}[aria-label='Review this task']"
    assert_select "form[action='#{migration_future_tasks_path(timed_task)}']"
    assert_select "form[action='#{migration_future_strike_path(timed_task)}']"
    assert_select "form[action='#{migration_future_calendar_path(timed_task)}']", count: 0

    original = journal_snapshot
    post migration_future_calendar_path(timed_task)
    assert_redirected_to migration_future_path
    assert_equal original, journal_snapshot

    post migration_future_tasks_path(timed_task)
    task_successor = timed_task.reload.successor
    assert_equal [ "monthly_tasks", TARGET_MONTH, nil, nil, "open" ],
      task_successor.values_at(:page_kind, :page_on, :occurs_on, :time_of_day, :state)
    assert_equal [ "migrated", ">" ], [ timed_task.state, timed_task.glyph ]

    get migration_future_path
    assert_select "#entry_#{untimed_event.id}"
    assert_select "form[action='#{migration_future_calendar_path(untimed_event)}']"
    assert_select "form[action='#{migration_future_tasks_path(untimed_event)}']", count: 0
    assert_select "form[action='#{migration_future_strike_path(untimed_event)}']", count: 0

    [ migration_future_tasks_path(untimed_event), migration_future_strike_path(untimed_event) ].each do |path|
      original = journal_snapshot
      post path
      assert_redirected_to migration_future_path
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original, journal_snapshot
    end

    post migration_future_calendar_path(untimed_event)
    event_successor = untimed_event.reload.successor
    assert_equal [ "monthly_calendar", TARGET_MONTH, untimed_event.occurs_on, nil, nil ],
      event_successor.values_at(:page_kind, :page_on, :occurs_on, :time_of_day, :state)
    assert_nil untimed_event.state
    assert_equal ">", untimed_event.glyph
  end

  test "empty stages require explicit scan and finish before live completion" do
    due_task = create_entry(
      text: "strike due task", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 7.days
    )

    post migration_future_strike_path(due_task)
    assert_redirected_to migration_future_path
    assert_equal "struck", due_task.reload.state
    follow_redirect!
    assert_select ".monthly-migration__stage", text: "Scan the Future Log"
    assert_select ".monthly-migration__checkpoint p", text: "Nothing due for September."
    assert_select "a[href='#{migration_complete_path}']", text: "Finish Monthly Migration"
    assert_select ".monthly-migration__complete", count: 0

    get migration_complete_path
    assert_select ".monthly-migration__complete h2", text: "Monthly Migration complete"
    assert_select "a", text: "September Calendar"
    assert_select "a", text: "September Tasks"

    late_source = create_entry(text: "work appeared later", page_kind: "daily", page_on: SOURCE_MONTH + 20.days)
    get migration_complete_path
    assert_redirected_to migration_outgoing_path
    follow_redirect!
    assert_select "#entry_#{late_source.id}"

    get migration_future_path
    assert_redirected_to migration_outgoing_path
  end

  test "an empty outgoing stage renders its own checkpoint before the Future scan" do
    get migration_outgoing_path

    assert_response :success
    assert_select ".monthly-migration__stage", text: "Review outgoing tasks"
    assert_select ".monthly-migration__checkpoint p", text: "No unresolved outgoing tasks."
    assert_select "a[href='#{migration_future_path}']", text: "Scan the Future Log"
    assert_select ".monthly-migration__complete", count: 0

    get migration_future_path
    assert_response :success
    assert_select ".monthly-migration__stage", text: "Scan the Future Log"
    assert_select ".monthly-migration__checkpoint p", text: "Nothing due for September."
    assert_select "a[href='#{migration_complete_path}']", text: "Finish Monthly Migration"
    assert_select ".monthly-migration__complete", count: 0
  end

  test "missing foreign and deleted item ids share the themed non-disclosing 404" do
    foreign = create_entry(
      user: @other_user, text: "foreign secret migration words", page_kind: "monthly_tasks", page_on: SOURCE_MONTH
    )
    deleted = create_entry(text: "deleted secret migration words", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    deleted.soft_delete!

    [ SecureRandom.uuid, foreign.id, deleted.id ].each do |id|
      post migration_outgoing_strike_path(id), params: { topic: "Secret Topic" }

      assert_response :not_found
      assert_select "h1", text: "Migration item not found", count: 1
      assert_select ".tab-bar__item--active[aria-current='page']", text: "Month"
      assert_no_match(/#{Regexp.escape(id)}|foreign secret|deleted secret|Secret Topic/, response.body)
    end
  end

  private

  def migration_path(month = TARGET_MONTH)
    value = month.respond_to?(:strftime) ? month.strftime("%Y-%m") : month
    monthly_migration_path(month: value)
  end

  def migration_inventory_path
    monthly_migration_inventory_path(month: TARGET_MONTH.strftime("%Y-%m"))
  end

  def migration_outgoing_path
    monthly_migration_outgoing_path(month: TARGET_MONTH.strftime("%Y-%m"))
  end

  def migration_outgoing_strike_path(entry)
    strike_monthly_migration_outgoing_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_outgoing_tasks_path(entry)
    tasks_monthly_migration_outgoing_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_outgoing_collection_path(entry)
    collection_monthly_migration_outgoing_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_outgoing_future_path(entry)
    future_monthly_migration_outgoing_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_future_path
    monthly_migration_future_path(month: TARGET_MONTH.strftime("%Y-%m"))
  end

  def migration_future_strike_path(entry)
    strike_monthly_migration_future_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_future_tasks_path(entry)
    tasks_monthly_migration_future_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_future_calendar_path(entry)
    calendar_monthly_migration_future_path(month: TARGET_MONTH.strftime("%Y-%m"), id: entry)
  end

  def migration_complete_path
    monthly_migration_complete_path(month: TARGET_MONTH.strftime("%Y-%m"))
  end

  def assert_title_first
    assert_select "main > h1:first-child", text: "Monthly Migration", count: 1
  end

  def create_outgoing_exclusions
    create_entry(text: "done", state: "done", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    create_entry(text: "struck", state: "struck", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    moved = create_entry(text: "already moved", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    moved.move_to!(page_kind: "monthly_tasks", page_on: TARGET_MONTH, as_of: AS_OF)
    deleted = create_entry(text: "deleted", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    deleted.soft_delete!
    hidden_root = create_entry(text: "hidden root", page_kind: "daily", page_on: SOURCE_MONTH + 1.day)
    create_entry(text: "hidden descendant", page_kind: "daily", page_on: SOURCE_MONTH + 1.day, parent: hidden_root)
    hidden_root.soft_delete!
    visible_root = create_entry(
      text: "visible context", kind: "note", state: nil,
      page_kind: "daily", page_on: SOURCE_MONTH + 1.day
    )
    hidden_child = create_entry(
      text: "deleted nested task", page_kind: "daily", page_on: SOURCE_MONTH + 1.day, parent: visible_root
    )
    create_entry(
      text: "descendant below deleted task", page_kind: "daily",
      page_on: SOURCE_MONTH + 1.day, parent: hidden_child
    )
    hidden_child.soft_delete!
    create_entry(text: "wrong month", page_kind: "monthly_tasks", page_on: SOURCE_MONTH.prev_month)
    create_entry(text: "future excluded", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH.next_month + 1.day)
    collection = @user.collections.create!(name: "Not a source")
    create_entry(text: "collection excluded", page_kind: "collection", page_on: nil, collection: collection)
  end

  def create_future_exclusions
    create_entry(text: "overdue", page_kind: "future", page_on: nil, occurs_on: SOURCE_MONTH + 2.days)
    create_entry(text: "later", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH.next_month + 2.days)
    create_entry(text: "done due", state: "done", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 2.days)
    moved = create_entry(text: "moved due", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 2.days)
    moved.move_to!(page_kind: "monthly_tasks", page_on: TARGET_MONTH, as_of: AS_OF)
    deleted = create_entry(text: "deleted due", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 2.days)
    deleted.soft_delete!
  end

  def create_entry(id: nil, user: @user, text:, kind: "task", state: :default, page_kind:, page_on:,
    parent: nil, collection: nil, occurs_on: nil, time_of_day: nil, priority: false, tags: [], created_at: nil)
    attributes = {
      user: user,
      text: text,
      kind: kind,
      state: state == :default ? ("open" if kind == "task") : state,
      tags: tags,
      page_kind: page_kind,
      page_on: page_on,
      parent: parent,
      collection: collection,
      occurs_on: occurs_on,
      time_of_day: time_of_day,
      priority: priority
    }
    attributes[:id] = id if id
    attributes[:created_at] = created_at if created_at
    user.entries.create!(attributes)
  end

  def journal_snapshot
    Entry.unscoped.order(:id).map(&:attributes)
  end

  def timestamp
    Time.zone.parse("2026-08-01 09:00:00")
  end

  def uuid(number)
    "0198f3ba-0000-7000-8000-#{number.to_s.rjust(12, '0')}"
  end
end
