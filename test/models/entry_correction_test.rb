require "test_helper"

# Pins correction and compensating movement to Entry's history-preserving
# domain boundary rather than controller parameters or browser state.
class EntryCorrectionTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 8, 26)

  setup do
    @user = users(:one)
  end

  test "correction replaces every editable field while preserving lifecycle and identity" do
    entry = create_entry(
      state: "done",
      text: "old words",
      priority: false,
      tags: %w[old],
      occurs_on: TODAY,
      time_of_day: "08:00",
      hlc: "dormant-hlc",
      server_seq: 41
    )
    immutable = entry.attributes.slice(
      "id", "user_id", "page_kind", "page_on", "collection_id", "parent_id",
      "migrated_from_id", "created_at", "deleted_at", "hlc", "server_seq"
    )
    parsed = parse("* corrected words +first +second 2026-08-29 14:35", kind: :task)

    entry.correct!(parsed, kind: "task")

    assert_equal [ "task", "done", "corrected words", true, %w[first second], Date.new(2026, 8, 29), "14:35" ],
      entry.reload.values_at(:kind, :state, :text, :priority, :tags, :occurs_on, :time_of_day)
    assert_equal immutable, entry.attributes.slice(*immutable.keys)
  end

  test "standalone unresolved entries convert kinds with exact state semantics" do
    task = create_entry
    task.correct!(parse("event words", kind: :event), kind: "event")
    assert_equal [ "event", nil ], task.reload.values_at(:kind, :state)

    task.correct!(parse("task again", kind: :task), kind: "task")
    assert_equal [ "task", "open" ], task.reload.values_at(:kind, :state)
  end

  test "done and struck tasks refuse kind changes until reopened" do
    %w[done struck].each do |state|
      entry = create_entry(state: state, text: "#{state} words")
      original = entry.attributes

      assert_raises(Entry::LifecycleError) do
        entry.correct!(parse("reinterpreted as event", kind: :event), kind: "event")
      end

      assert_equal original, entry.reload.attributes
    end
  end

  test "nil parse and unknown kind refuse correction without a write" do
    entry = create_entry(text: "unchanged")
    original = entry.attributes

    assert_raises(Entry::LifecycleError) { entry.correct!(nil, kind: "task") }
    assert_raises(Entry::LifecycleError) { entry.correct!(parse("still a task"), kind: "bogus") }

    assert_equal original, entry.reload.attributes
  end

  test "kind correction obeys the persisted page vocabulary" do
    future = create_entry(page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)

    assert_raises(Entry::LifecycleError) do
      future.correct!(parse("not allowed", kind: :note), kind: "note")
    end

    assert_equal [ "task", "open" ], future.reload.values_at(:kind, :state)
  end

  test "a Future Note child keeps its valid current kind without opening the root vocabulary" do
    root = create_entry(page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    child = create_entry(
      kind: "note", state: nil, text: "old child words", tags: %w[old],
      page_kind: "future", page_on: nil, occurs_on: nil, parent: root
    )
    immutable = child.attributes.slice(
      "id", "user_id", "page_kind", "page_on", "collection_id", "parent_id",
      "migrated_from_id", "created_at", "deleted_at", "hlc", "server_seq"
    )

    child.correct!(parse("new child words +camp", kind: :note), kind: "note")

    assert_equal [ "note", nil, "new child words", %w[camp], nil, nil ],
      child.reload.values_at(:kind, :state, :text, :tags, :occurs_on, :time_of_day)
    assert_equal immutable, child.attributes.slice(*immutable.keys)
    assert_equal %w[task event], Entry::ROOT_KINDS.fetch("future")

    %w[task event].each do |kind|
      context = create_entry(
        kind: kind, state: ("open" if kind == "task"),
        page_kind: "future", page_on: nil, occurs_on: nil, parent: root
      )
      original = context.attributes

      assert_raises(Entry::LifecycleError) do
        context.correct!(parse("not a Note", kind: :note), kind: "note")
      end
      assert_equal original, context.reload.attributes
    end
  end

  test "a Future Note child may still change to Task or Event on the same parent" do
    root = create_entry(page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    child = create_entry(
      kind: "note", state: nil, text: "old child words",
      page_kind: "future", page_on: nil, occurs_on: nil, parent: root
    )

    assert_equal %w[task event], root.correctable_kinds
    assert_equal %w[task event note], child.correctable_kinds

    child.correct!(parse("now a task", kind: :task), kind: "task")
    assert_equal [ "task", "open", "now a task", root.id ],
      child.reload.values_at(:kind, :state, :text, :parent_id)

    child.correct!(parse("now an event", kind: :event), kind: "event")
    assert_equal [ "event", nil, "now an event", root.id ],
      child.reload.values_at(:kind, :state, :text, :parent_id)
    assert_equal %w[task], root.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY
    ).correctable_kinds
  end

  test "moved predecessors refuse correction while live ends keep their inherited kind" do
    predecessor = create_entry(text: "original")
    live_end = predecessor.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY
    )

    assert_raises(Entry::LifecycleError) do
      predecessor.correct!(parse("rewrite history"), kind: "task")
    end
    assert_raises(Entry::LifecycleError) do
      live_end.correct!(parse("wrong kind", kind: :event), kind: "event")
    end

    live_end.correct!(parse("correct current words +kept"), kind: "task")
    assert_equal [ "task", "open", "correct current words", %w[kept] ],
      live_end.reload.values_at(:kind, :state, :text, :tags)
    assert_equal "original", predecessor.reload.text
  end

  test "invalid correction is atomic and leaves timestamps and domain fields unchanged" do
    calendar = create_entry(
      page_kind: "monthly_calendar",
      page_on: TODAY.beginning_of_month,
      occurs_on: TODAY,
      text: "calendar words"
    )
    original = calendar.attributes

    assert_raises(ActiveRecord::RecordInvalid) do
      calendar.correct!(parse("outside resident month 2026-09-01"), kind: "task")
    end

    assert_equal original, calendar.reload.attributes
  end

  test "canonical edit line omits lifecycle glyph and preserves metadata order" do
    entry = create_entry(
      state: "done", text: "pay invoice", priority: true, tags: %w[work urgent],
      occurs_on: Date.new(2026, 8, 30), time_of_day: "09:05"
    )

    assert_equal "* pay invoice +work +urgent 2026-08-30 09:05", entry.canonical_edit_line
  end

  test "compensating movement appends a third row at the exact source residency" do
    source = create_entry(
      page_kind: "future", page_on: nil, occurs_on: Date.new(2026, 8, 4),
      time_of_day: "07:45", priority: true, tags: %w[trip], text: "source words"
    )
    moved = source.move_to!(
      page_kind: "monthly_tasks", page_on: TODAY.beginning_of_month, as_of: TODAY
    )
    moved.correct!(parse("current live words +changed"), kind: "task")

    restored = moved.compensate_to!(source)

    assert_equal [ source, moved, restored ], [ restored.predecessor.predecessor, restored.predecessor, restored ]
    assert_equal "migrated", moved.reload.state
    assert_equal [ "task", "open", "current live words", false, %w[changed] ],
      restored.values_at(:kind, :state, :text, :priority, :tags)
    assert_equal [ "future", nil, nil, Date.new(2026, 8, 4), "07:45" ],
      restored.values_at(:page_kind, :page_on, :collection_id, :occurs_on, :time_of_day)
    assert_uuid_v7 restored.id
    assert_equal 2, restored.carried_count
  end

  private

  def create_entry(overrides = {})
    @user.entries.create!({
      kind: "task", state: "open", text: "entry words", priority: false, tags: [],
      page_kind: "daily", page_on: TODAY
    }.merge(overrides))
  end

  def parse(line, kind: :task)
    Bujo::RapidLog.parse(line, today: TODAY, default_kind: kind)
  end
end
