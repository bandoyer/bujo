require "test_helper"

class CoreNotationHierarchyTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 8, 28)

  test "capture correction movement and compensation preserve independent signifiers" do
    source = Entry.capture!(
      "* ! • Protect the quiet hour",
      user: users(:one), today: TODAY, as_of: TODAY,
      page_kind: "daily", page_on: TODAY
    )
    assert_equal [ true, true ], source.values_at(:priority, :inspiration)

    parsed = Bujo::RapidLog.parse("! Protect the quiet hour", today: TODAY)
    source.correct!(parsed, kind: "task")
    assert_equal [ false, true, "! Protect the quiet hour" ],
      [ source.reload.priority?, source.inspiration?, source.canonical_edit_line ]

    successor = source.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY
    )
    assert_equal [ false, true ], successor.values_at(:priority, :inspiration)
    successor.mark_priority!
    assert_equal [ true, true ], successor.reload.values_at(:priority, :inspiration)

    restored = successor.compensate_to!(source)
    assert_equal [ true, true ], restored.values_at(:priority, :inspiration)
    assert_equal [ false, true ], source.reload.values_at(:priority, :inspiration)
  end

  test "completion follows kept descendants and current movement endpoints without cascading" do
    master = create_entry(text: "Master")
    context = create_entry(text: "Context", kind: "note", state: nil, parent: master)
    subtask = create_entry(text: "Nested task", parent: context)

    assert_not master.completable?
    assert_raises(Entry::LifecycleError) { master.complete! }
    assert_equal %w[open open], [ master.reload.state, subtask.reload.state ]

    successor = subtask.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY
    )
    assert_not master.reload.completable?
    successor.strike!
    assert_predicate master.reload, :completable?

    master.complete!
    assert_equal "done", master.reload.state
    assert_equal "struck", successor.reload.state
    assert_nil context.reload.state
  end

  test "deleted child cuts off its branch while malformed movement ends block" do
    master = create_entry(text: "Master")
    deleted_context = create_entry(text: "Deleted context", kind: "note", state: nil, parent: master)
    create_entry(text: "Hidden blocker", parent: deleted_context)
    deleted_context.soft_delete!
    assert_predicate master.reload, :completable?

    blocker = create_entry(text: "Moved blocker", parent: master)
    blocker.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
    blocker.successor.soft_delete!

    assert_not master.reload.completable?
    assert_raises(Entry::LifecycleError) { master.complete! }
    assert_equal "open", master.reload.state
  end

  test "child capture derives ownership placement ancestry parser context and UUID" do
    parent = create_entry(text: "Parent", page_kind: "monthly_calendar",
      page_on: TODAY.beginning_of_month, occurs_on: TODAY)

    child = Entry.capture_child!(
      "! – Supporting thought tomorrow",
      parent: parent, user: users(:one), today: parent.occurs_on, as_of: TODAY,
      default_kind: :task
    )

    assert_uuid_v7 child.id
    assert_equal [ users(:one), parent, "monthly_calendar", TODAY.beginning_of_month, nil ],
      child.values_at(:user, :parent, :page_kind, :page_on, :collection)
    assert_equal [ "note", nil, true, TODAY.next_day ],
      child.values_at(:kind, :state, :inspiration, :occurs_on)
  end

  test "child capture refuses unwritable or stale parents and blank input is a no-op" do
    future_daily = create_entry(text: "Tomorrow", page_on: TODAY.next_day)
    future_log = create_entry(text: "Later", page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    done = create_entry(text: "Done", state: "done")
    moved = create_entry(text: "Moved")
    moved.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
    hidden_root = create_entry(text: "Hidden root")
    nested_parent = create_entry(text: "Hidden child", parent: hidden_root)
    hidden_root.soft_delete!

    assert_nil Entry.capture_child!("   ", parent: create_entry, user: users(:one), today: TODAY, as_of: TODAY)
    [ future_daily, future_log, done, moved, nested_parent.reload ].each do |parent|
      assert_raises(Entry::LifecycleError) do
        Entry.capture_child!("child", parent: parent, user: users(:one), today: TODAY, as_of: TODAY)
      end
    end
  end

  test "event and note children never block while a foreign done successor still does" do
    master = create_entry(text: "Master")
    note = create_entry(text: "Context", kind: "note", state: nil, parent: master)
    event = create_entry(text: "Date", kind: "event", state: nil, parent: master)
    assert_predicate master.reload, :completable?

    blocker = create_entry(text: "Moved", parent: master)
    successor = blocker.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY
    )
    successor.update_columns(user_id: users(:two).id, state: "done")
    original = [ master, note, event, blocker, successor ].map { |row| row.reload.attributes }

    assert_not master.reload.completable?
    assert_raises(Entry::LifecycleError) { master.complete! }
    assert_equal original, [ master, note, event, blocker, successor ].map { |row| row.reload.attributes }
  end

  test "done and struck children admit complete without cascading or reopening later work" do
    master = create_entry(text: "Master")
    done_child = create_entry(text: "Done child", state: "done", parent: master)
    struck_child = create_entry(text: "Struck child", state: "struck", parent: master)

    master.complete!
    late = create_entry(text: "Afterward", parent: master)
    assert_equal [ "done", "done", "struck", "open" ],
      [ master.reload, done_child.reload, struck_child.reload, late ].map(&:state)
    assert_not master.completable?
  end

  test "collection child capture copies the parent's collection and mark priority keeps inspiration" do
    parent = create_entry(
      text: "Pack", page_kind: "collection", page_on: nil, collection: collections(:camping)
    )
    child = Entry.capture_child!(
      "• Nested chore", parent: parent, user: users(:one), today: TODAY, as_of: TODAY
    )
    assert_equal [ users(:one), parent, "collection", nil, collections(:camping) ],
      child.values_at(:user, :parent, :page_kind, :page_on, :collection)

    inspired = create_entry(text: "Keep this", inspiration: true)
    original = inspired.attributes.except("priority", "updated_at")
    inspired.mark_priority!
    assert_equal [ true, true ], inspired.reload.values_at(:priority, :inspiration)
    assert_equal original, inspired.attributes.except("priority", "updated_at")
  end

  private

  def create_entry(overrides = {})
    Entry.create!({
      user: users(:one), kind: "task", state: "open", text: "Task",
      priority: false, inspiration: false, tags: [], page_kind: "daily", page_on: TODAY
    }.merge(overrides))
  end
end
