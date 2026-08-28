require "test_helper"

# Pins the current-day Daily Reflection lens, its exact source membership, and
# the one priority mutation it adds to the journal domain.
class DailyReflectionsControllerTest < ActionDispatch::IntegrationTest
  TODAY = Date.new(2026, 8, 27)
  MONTH = TODAY.beginning_of_month

  setup do
    @user = users(:one)
    @other_user = users(:two)
    @user.entries.update_all(deleted_at: Time.current)
    @other_user.entries.update_all(deleted_at: Time.current)
    sign_in_as @user
  end

  test "both modes require authentication and snapshot the request day once" do
    sign_out

    get reflection_path
    assert_redirected_to new_session_path
    get evening_reflection_path
    assert_redirected_to new_session_path

    sign_in_as @user
    clock_reads = 0
    zone = Time.zone
    zone.define_singleton_method(:today) do
      clock_reads += 1
      TODAY
    end

    begin
      get reflection_path
      morning_reads = clock_reads
      get evening_reflection_path, params: { date: "2026-01-01", on: "2026-01-01", month: "2026-01" }
    ensure
      zone.singleton_class.remove_method(:today)
    end

    assert_response :success
    assert_equal 1, morning_reads
    assert_equal 2, clock_reads
    assert_select "main > h1:first-child", text: "Daily Reflection", count: 1
    assert_select "h1", count: 1
    assert_select "main.page-shell.daily-reflection[data-turbo=false]"
    assert_select ".daily-reflection__date", text: TODAY.strftime("%A · %B %-d").upcase
    assert_select ".tab-bar__item--active[aria-current='page']", text: "Today"
  end

  test "an unmatched Reflection path is an ordinary route miss" do
    [ "/reflection/yesterday", "/reflection/2026-08-26" ].each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path)
      end
    end
  end

  test "Morning renders qualifying kept trees in Calendar Tasks and Daily paper order" do
    calendar_root = create_entry(
      id: uuid(101), text: "calendar context", kind: "event", page_kind: "monthly_calendar",
      page_on: MONTH, occurs_on: MONTH + 3.days, created_at: timestamp
    )
    calendar_task = create_entry(
      id: uuid(102), text: "nested calendar task", page_kind: "monthly_calendar",
      page_on: MONTH, occurs_on: MONTH + 3.days, parent: calendar_root, created_at: timestamp
    )
    monthly_task = create_entry(
      id: uuid(103), text: "monthly task", page_kind: "monthly_tasks", page_on: MONTH,
      created_at: timestamp
    )
    daily_root = create_entry(
      id: uuid(104), text: "daily note context", kind: "note", page_kind: "daily",
      page_on: MONTH + 14.days, created_at: timestamp
    )
    daily_task = create_entry(
      id: uuid(105), text: "nested daily task", page_kind: "daily",
      page_on: MONTH + 14.days, parent: daily_root, created_at: timestamp
    )
    create_morning_exclusions

    travel_to TODAY do
      get reflection_path
    end

    assert_response :success
    assert_select "nav[aria-label='Daily Reflection mode'] a[aria-current='page']", text: "Morning"
    assert_select "label[for='reflection_line']", text: "What surfaced overnight?"
    assert_select ".daily-reflection__open-count", text: "3 open"
    [ calendar_root, calendar_task, monthly_task, daily_root, daily_task ].each do |entry|
      assert_select "#entry_#{entry.id}", count: 1
    end
    assert_select "#entry_#{calendar_root.id} #entry_#{calendar_task.id}"
    assert_select "#entry_#{daily_root.id} #entry_#{daily_task.id}"
    assert_select "form[action='#{mark_priority_reflection_path(calendar_task)}']", count: 1
    assert_select "form[action='#{mark_priority_reflection_path(calendar_root)}']", count: 0
    assert_select "form[action='#{complete_entry_path(calendar_task)}']", count: 0
    assert_select "form[action='#{strike_entry_path(calendar_task)}']", count: 0
    assert_select "form[action='#{schedule_entry_path(calendar_task)}']", count: 0
    assert_body_order(
      "Monthly Calendar · August 2026",
      "nested calendar task",
      "Monthly Tasks · August 2026",
      "monthly task",
      "Daily Log · August 15, 2026",
      "nested daily task"
    )
    %w[done struck migrated successor-bearing deleted hidden-descendant future collection prior-month future-day foreign].each do |text|
      assert_select ".entry__text", text: text, count: 0
    end
  end

  test "Morning keeps a non-task ancestor and sibling as context but omits roots without eligible tasks" do
    qualifying = create_entry(text: "qualifying root", kind: "note", page_kind: "daily", page_on: TODAY)
    create_entry(text: "visible sibling", kind: "event", page_kind: "daily", page_on: TODAY, parent: qualifying)
    create_entry(text: "eligible descendant", page_kind: "daily", page_on: TODAY, parent: qualifying)
    irrelevant = create_entry(text: "context-only root", kind: "note", page_kind: "daily", page_on: TODAY)
    create_entry(text: "settled descendant", state: "done", page_kind: "daily", page_on: TODAY, parent: irrelevant)

    travel_to TODAY do
      get reflection_path
    end

    assert_select ".entry__text", text: "qualifying root"
    assert_select ".entry__text", text: "visible sibling"
    assert_select ".entry__text", text: "eligible descendant"
    assert_select "#entry_#{irrelevant.id}", count: 0
    assert_select ".daily-reflection__open-count", text: "1 open"
  end

  test "Morning membership follows dated-page residency through today, not occurs_on" do
    first_of_month = create_entry(text: "first-of-month daily", page_kind: "daily", page_on: MONTH)
    create_entry(text: "prior-month daily dated today", page_kind: "daily", page_on: MONTH.prev_day, occurs_on: TODAY)
    create_entry(
      text: "prior-month calendar", page_kind: "monthly_calendar",
      page_on: MONTH.prev_month, occurs_on: MONTH.prev_month + 3.days
    )
    create_entry(text: "occurs-on today future", page_kind: "future", page_on: nil, occurs_on: TODAY)

    travel_to TODAY do
      get reflection_path
    end

    assert_select "#entry_#{first_of_month.id}", count: 1
    assert_select "form[action='#{mark_priority_reflection_path(first_of_month)}']", count: 1
    %w[prior-month\ daily\ dated\ today prior-month\ calendar occurs-on\ today\ future].each do |text|
      assert_select ".entry__text", text: text, count: 0
    end
  end

  test "Morning empty state makes no completion claim" do
    travel_to TODAY do
      get reflection_path
    end

    assert_select ".daily-reflection__empty", text: "No open tasks on this month's pages."
    assert_select ".daily-reflection__empty", text: /planned|complete/i, count: 0
  end

  test "priority mark and clear revalidate membership and preserve order and all other fields" do
    task = create_entry(text: "priority candidate", page_kind: "monthly_tasks", page_on: MONTH)

    travel_to TODAY do
      original = task.attributes.except("priority", "updated_at")
      post mark_priority_reflection_path(task), params: { page_kind: "future", on: TODAY.next_day.iso8601 }
      assert_redirected_to reflection_path
      assert_equal "entry:#{task.id}", flash[:reflection_focus]
      assert_predicate task.reload, :priority?
      assert_equal original, task.attributes.except("priority", "updated_at")

      post clear_priority_reflection_path(task)
      assert_redirected_to reflection_path
      assert_equal "entry:#{task.id}", flash[:reflection_focus]
      assert_not task.reload.priority?
      assert_equal original, task.attributes.except("priority", "updated_at")
    end
  end

  test "mode and Schedule entry requests redirect with one-response focus state" do
    task = create_entry(text: "schedule candidate", page_kind: "daily", page_on: TODAY)
    event = create_entry(text: "schedule event", kind: "event", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      get reflection_path, params: { focus: "mode" }
      assert_redirected_to reflection_path
      assert_equal "mode", flash[:reflection_focus]
      follow_redirect!
      assert_select "a#reflection_morning_mode[autofocus]"
      assert_select "a#reflection_evening_mode[autofocus]", count: 0

      get evening_reflection_path, params: { focus: "mode" }
      assert_redirected_to evening_reflection_path
      assert_equal "mode", flash[:reflection_focus]
      follow_redirect!
      assert_select "a#reflection_evening_mode[autofocus]"
      assert_select "a#reflection_morning_mode[autofocus]", count: 0

      get evening_reflection_path, params: { schedule: task.id }
      assert_redirected_to evening_reflection_path
      assert_equal "schedule:#{task.id}", flash[:reflection_focus]
      follow_redirect!
      assert_select "#entry_#{task.id}.entry--selected input[type=date][autofocus]"
      assert_select "#entry_#{task.id} .entry__toggle[aria-expanded=true][autofocus]", count: 0

      get evening_reflection_path, params: { schedule: event.id }
      assert_equal "schedule:#{event.id}", flash[:reflection_focus]
    end
  end

  test "crafted focus and Schedule hints cannot authorize a write or open an ineligible row" do
    note = create_entry(text: "today note", kind: "note", page_kind: "daily", page_on: TODAY)
    done = create_entry(text: "today done", state: "done", page_kind: "daily", page_on: TODAY)
    monthly = create_entry(text: "monthly task", page_kind: "monthly_tasks", page_on: MONTH)
    foreign = create_entry(user: @other_user, text: "foreign evening", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      snapshot = journal_snapshot

      get reflection_path, params: { schedule: monthly.id, focus: "capture", page_kind: "future" }
      assert_response :success
      assert_nil flash[:reflection_focus]
      assert_select ".entry--selected", count: 0

      [ note.id, done.id, monthly.id, foreign.id, SecureRandom.uuid ].each do |id|
        get evening_reflection_path, params: { schedule: id, return_to: "https://attacker.example" }
        assert_redirected_to evening_reflection_path
        assert_equal "mode", flash[:reflection_focus]
        assert_equal snapshot, journal_snapshot
      end

      follow_redirect!
      assert_select "a#reflection_evening_mode[autofocus]"
      assert_select ".entry--selected", count: 0
      assert_select "input[type=date][autofocus]", count: 0
    end
  end

  test "priority refuses every stale ineligible or mismatched current-user target atomically" do
    collection = @user.collections.create!(name: "Private work")
    cases = [
      create_entry(text: "wrong prior month", page_kind: "monthly_tasks", page_on: MONTH.prev_month),
      create_entry(text: "wrong future", page_kind: "future", page_on: nil, occurs_on: TODAY.next_month),
      create_entry(text: "wrong collection", page_kind: "collection", page_on: nil, collection: collection),
      create_entry(text: "wrong future day", page_kind: "daily", page_on: TODAY.next_day),
      create_entry(text: "wrong done", state: "done", page_kind: "daily", page_on: TODAY),
      create_entry(text: "wrong struck", state: "struck", page_kind: "daily", page_on: TODAY)
    ]
    moved = create_entry(text: "wrong moved", page_kind: "daily", page_on: TODAY)
    moved.move_to!(page_kind: "monthly_tasks", page_on: MONTH.next_month, as_of: TODAY)
    cases << moved

    travel_to TODAY do
      cases.each do |task|
        snapshot = journal_snapshot
        post mark_priority_reflection_path(task)
        assert_redirected_to reflection_path
        assert_equal "That entry can't do that.", flash[:alert]
        assert_equal "mode", flash[:reflection_focus]
        assert_equal snapshot, journal_snapshot
      end

      marked = create_entry(text: "already marked", page_kind: "daily", page_on: TODAY, priority: true)
      snapshot = journal_snapshot
      post mark_priority_reflection_path(marked)
      assert_equal snapshot, journal_snapshot
      assert_equal "entry:#{marked.id}", flash[:reflection_focus]
    end
  end

  test "priority missing foreign and deleted ids are uniformly non-disclosing" do
    foreign = create_entry(
      user: @other_user, text: "foreign secret", page_kind: "daily", page_on: TODAY
    )
    deleted = create_entry(text: "deleted secret", page_kind: "daily", page_on: TODAY)
    deleted.soft_delete!

    travel_to TODAY do
      [ SecureRandom.uuid, foreign.id, deleted.id ].each do |id|
        [ mark_priority_reflection_path(id), clear_priority_reflection_path(id) ].each do |path|
          original = journal_snapshot
          post path
          assert_response :not_found
          assert_empty response.body
          assert_equal original, journal_snapshot
        end
      end
    end
  end

  test "Evening renders only today's complete kept Daily trees and derives done copy" do
    root = create_entry(text: "today root", page_kind: "daily", page_on: TODAY)
    child = create_entry(text: "done child", state: "done", page_kind: "daily", page_on: TODAY, parent: root)
    nested_open = create_entry(text: "open child", page_kind: "daily", page_on: TODAY, parent: root)
    event = create_entry(text: "today event", kind: "event", page_kind: "daily", page_on: TODAY)
    note = create_entry(text: "today note", kind: "note", page_kind: "daily", page_on: TODAY)
    create_evening_exclusions

    travel_to TODAY do
      get evening_reflection_path
    end

    assert_response :success
    assert_select "nav[aria-label='Daily Reflection mode'] a[aria-current='page']", text: "Evening"
    assert_select "label[for='reflection_line']", text: "What did you miss?"
    [ root, child, nested_open, event, note ].each { |entry| assert_select "#entry_#{entry.id}", count: 1 }
    assert_select "#entry_#{root.id} form[action='#{complete_entry_path(root)}']"
    assert_select "#entry_#{root.id} form[action='#{strike_entry_path(root)}']"
    assert_select "#entry_#{root.id} form[action='#{schedule_entry_path(root)}']"
    assert_select "#entry_#{nested_open.id} form[action='#{complete_entry_path(nested_open)}']"
    assert_select "#entry_#{event.id} form[action='#{schedule_entry_path(event)}']"
    assert_select "#entry_#{note.id} form", count: 0
    assert_select "#entry_#{child.id} form", count: 0
    [ root, nested_open ].each do |entry|
      assert_select "#entry_#{entry.id} button", text: "Edit", count: 0
      assert_select "#entry_#{entry.id} form[action='#{migrate_entry_path(entry)}']", count: 0
      assert_select "#entry_#{entry.id} form[action='#{reopen_entry_path(entry)}']", count: 0
      assert_select "#entry_#{entry.id} form[action='#{move_to_collection_entry_path(entry)}']", count: 0
    end
    assert_select ".daily-reflection__progress", text: "1 task marked complete."
    assert_select ".daily-reflection__closing", text: "Notice what moved forward today."
    %w[prior-day monthly future collection deleted hidden-evening foreign-evening other-page-done monthly-done].each do |text|
      assert_select ".entry__text", text: text, count: 0
    end
  end

  test "Evening pluralizes positive done count and omits numeric copy at zero" do
    travel_to TODAY do
      get evening_reflection_path
      assert_select ".daily-reflection__empty", text: "Nothing logged today yet."
      assert_select ".daily-reflection__progress", count: 0

      2.times do |index|
        create_entry(text: "done #{index}", state: "done", page_kind: "daily", page_on: TODAY)
      end
      get evening_reflection_path
      assert_select ".daily-reflection__progress", text: "2 tasks marked complete."
    end
  end

  private

  def create_entry(id: nil, user: @user, text:, kind: "task", state: :default, page_kind:, page_on:,
    parent: nil, collection: nil, occurs_on: nil, priority: false, created_at: nil)
    user.entries.create!(
      id: id,
      text: text,
      kind: kind,
      state: state == :default ? ("open" if kind == "task") : state,
      tags: [],
      priority: priority,
      page_kind: page_kind,
      page_on: page_on,
      parent: parent,
      collection: collection,
      occurs_on: occurs_on,
      created_at: created_at
    )
  end

  def create_morning_exclusions
    create_entry(text: "done", state: "done", page_kind: "monthly_tasks", page_on: MONTH)
    create_entry(text: "struck", state: "struck", page_kind: "daily", page_on: TODAY)
    migrated = create_entry(text: "migrated", page_kind: "daily", page_on: TODAY)
    migrated.move_to!(page_kind: "monthly_tasks", page_on: MONTH.next_month, as_of: TODAY)
    predecessor = create_entry(text: "successor-bearing", kind: "event", page_kind: "daily", page_on: TODAY)
    predecessor.move_to!(page_kind: "future", page_on: nil, occurs_on: TODAY.next_month, as_of: TODAY)
    deleted = create_entry(text: "deleted", page_kind: "daily", page_on: TODAY)
    deleted.soft_delete!
    deleted_parent = create_entry(text: "deleted ancestor", kind: "note", page_kind: "daily", page_on: TODAY)
    create_entry(text: "hidden-descendant", page_kind: "daily", page_on: TODAY, parent: deleted_parent)
    deleted_parent.soft_delete!
    create_entry(text: "future", page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    collection = @user.collections.create!(name: "Excluded")
    create_entry(text: "collection", page_kind: "collection", page_on: nil, collection: collection)
    create_entry(text: "prior-month", page_kind: "monthly_tasks", page_on: MONTH.prev_month)
    create_entry(text: "future-day", page_kind: "daily", page_on: TODAY.next_day)
    create_entry(user: @other_user, text: "foreign", page_kind: "daily", page_on: TODAY)
  end

  def create_evening_exclusions
    create_entry(text: "prior-day", page_kind: "daily", page_on: TODAY.prev_day)
    create_entry(text: "monthly", page_kind: "monthly_tasks", page_on: MONTH)
    create_entry(text: "future", page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    collection = @user.collections.create!(name: "Evening excluded")
    create_entry(text: "collection", page_kind: "collection", page_on: nil, collection: collection)
    deleted = create_entry(text: "deleted", page_kind: "daily", page_on: TODAY)
    deleted.soft_delete!
    deleted_parent = create_entry(text: "deleted evening ancestor", kind: "note", page_kind: "daily", page_on: TODAY)
    create_entry(text: "hidden-evening", page_kind: "daily", page_on: TODAY, parent: deleted_parent)
    deleted_parent.soft_delete!
    create_entry(user: @other_user, text: "foreign-evening", page_kind: "daily", page_on: TODAY)
    create_entry(text: "other-page-done", state: "done", page_kind: "daily", page_on: TODAY.prev_day)
    create_entry(text: "monthly-done", state: "done", page_kind: "monthly_tasks", page_on: MONTH)
  end

  def journal_snapshot
    Entry.unscoped.order(:id).map { |entry| entry.attributes.except("updated_at") }
  end

  def assert_body_order(*fragments)
    offsets = fragments.map { |fragment| response.body.index(fragment) }
    assert offsets.all?, "missing ordered fragment"
    assert_equal offsets.sort, offsets
  end

  def timestamp
    Time.zone.parse("2026-08-27 09:00:00")
  end

  def uuid(number)
    format("0198f3b9-0000-7000-8000-%012d", number)
  end
end
