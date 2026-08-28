require "test_helper"

class EntryTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 8, 24)

  test "validates text, kind, task state, non-task state, and time" do
    assert_invalid entry(text: "  "), :text
    assert_invalid entry(kind: "reminder"), :kind
    assert_invalid entry(state: nil), :state
    assert_invalid entry(state: "waiting"), :state
    assert_invalid entry(kind: "event", state: "open"), :state
    assert_invalid entry(kind: "note", state: "done"), :state
    # The spec rules state to be exactly NULL on non-tasks, and an empty
    # string is a value: sync compares field values, so "" and NULL would
    # read as a conflict between two devices that agree.
    assert_invalid entry(kind: "event", state: ""), :state
    assert_invalid entry(kind: "note", state: ""), :state
    assert_predicate entry(kind: "event", state: nil), :valid?
    assert_predicate entry(kind: "note", state: nil), :valid?
    assert_predicate entry(time_of_day: nil), :valid?
    assert_predicate entry(time_of_day: "00:00"), :valid?
    assert_predicate entry(time_of_day: "23:59"), :valid?
    assert_invalid entry(time_of_day: "9:30"), :time_of_day
    assert_invalid entry(time_of_day: "24:00"), :time_of_day
    assert_invalid entry(time_of_day: "12:60"), :time_of_day
  end

  test "requires a parent to be another entry owned by the same user" do
    parent = entry
    child = entry(kind: "note", state: nil, parent: parent)

    assert_predicate child, :valid?
    assert_invalid entry(parent: entry(user: users(:two))), :parent
    assert_invalid parent.tap { |record| record.parent = record }, :parent
  end

  test "captures parser fields into one Daily residency" do
    captured = nil

    assert_difference -> { Entry.count }, 1 do
      captured = capture("call the vet friday +home")
    end

    assert_equal "task", captured.kind
    assert_equal "open", captured.state
    assert_equal "call the vet", captured.text
    assert_equal TODAY, captured.page_on
    assert_equal Date.new(2026, 8, 28), captured.occurs_on
    assert_equal [ "home" ], captured.tags
    assert_includes users(:one).entries.daily_log(TODAY), captured
    assert_not_includes users(:one).entries.monthly_calendar(TODAY), captured
    assert_not_includes users(:one).entries.daily_log(TODAY + 1), captured
  end

  test "captures done tasks, optional collections, and blank lines" do
    collection = collections(:camping)
    done = capture("x paid the invoice", page_kind: "collection", page_on: nil, collection: collection)

    assert_equal "done", done.state
    assert_equal collection, done.collection
    assert_not_includes users(:one).entries.daily_log(TODAY), done
    assert_not_includes users(:one).entries.open_tasks, done
    assert_no_difference -> { Entry.count } do
      assert_nil capture("   ")
    end
  end

  test "capture honors default kind and propagates invalid defaults" do
    note = capture("remember this", default_kind: :note)

    assert_equal "note", note.kind
    assert_nil note.state
    assert_raises(ArgumentError) do
      capture("words", default_kind: :bogus)
    end
  end

  test "capture maps priority and time fields from the parser" do
    event = capture("* o Dinner tomorrow 6pm +Home")

    assert_equal "event", event.kind
    assert_nil event.state
    assert_predicate event, :priority?
    assert_equal "Dinner", event.text
    assert_equal TODAY, event.page_on
    assert_equal TODAY + 1, event.occurs_on
    assert_equal "18:00", event.time_of_day
    assert_equal [ "home" ], event.tags
  end

  test "daily logs contain kept roots ordered by creation and id" do
    user = users(:two)
    date = Date.new(2030, 4, 3)
    timestamp = Time.zone.parse("2030-04-03 10:00:00")
    later_id = "0198f3b9-0000-7000-8000-000000000012"
    earlier_id = "0198f3b9-0000-7000-8000-000000000011"
    later = create_entry(user: user, id: later_id, page_on: date, created_at: timestamp)
    earlier = create_entry(user: user, id: earlier_id, page_on: date, created_at: timestamp)
    child = create_entry(user: user, page_on: date, parent: earlier, kind: "note", state: nil)
    deleted = create_entry(user: user, page_on: date, deleted_at: timestamp)
    create_entry(user: user, page_on: date + 1)

    assert_equal [ earlier, later ], user.entries.daily_log(date).to_a
    assert_not_includes user.entries.daily_log(date), child
    assert_not_includes user.entries.daily_log(date), deleted
  end

  test "monthly calendar orders timed entries before untimed entries with id ties" do
    user = users(:two)
    month = Date.new(2031, 5, 18)
    timestamp = Time.zone.parse("2031-05-01 08:00:00")
    late = create_entry(user: user, page_kind: "monthly_calendar", page_on: month.beginning_of_month, occurs_on: Date.new(2031, 5, 8), time_of_day: "11:00", created_at: timestamp)
    early = create_entry(user: user, page_kind: "monthly_calendar", page_on: month.beginning_of_month, occurs_on: Date.new(2031, 5, 8), time_of_day: "09:00", created_at: timestamp)
    untimed_later = create_entry(
      user: user,
      id: "0198f3b9-0000-7000-8000-000000000022",
      page_kind: "monthly_calendar",
      page_on: month.beginning_of_month,
      occurs_on: Date.new(2031, 5, 8),
      time_of_day: nil,
      created_at: timestamp
    )
    untimed_earlier = create_entry(
      user: user,
      id: "0198f3b9-0000-7000-8000-000000000021",
      page_kind: "monthly_calendar",
      page_on: month.beginning_of_month,
      occurs_on: Date.new(2031, 5, 8),
      time_of_day: nil,
      created_at: timestamp
    )
    create_entry(user: user, page_kind: "monthly_calendar", page_on: Date.new(2031, 6, 1), occurs_on: Date.new(2031, 6, 1))

    assert_equal [ early, late, untimed_earlier, untimed_later ], user.entries.monthly_calendar(month).to_a
  end

  test "monthly tasks include only residents in stable creation order" do
    user = users(:two)
    month = Date.new(2032, 7, 14)
    older = create_entry(user: user, page_kind: "monthly_tasks", page_on: month.beginning_of_month, created_at: Time.zone.parse("2032-07-01"))
    newer = create_entry(user: user, page_kind: "monthly_tasks", page_on: month.beginning_of_month, created_at: Time.zone.parse("2032-07-02"))
    create_entry(user: user, kind: "event", state: nil, page_kind: "daily", page_on: Date.new(2032, 7, 15))
    create_entry(user: user, page_kind: "monthly_tasks", page_on: Date.new(2032, 8, 1))

    assert_equal [ older, newer ], user.entries.monthly_tasks(month).to_a
  end

  test "future log uses dated ordering for every resident" do
    user = users(:two)
    boundary = Date.new(2033, 8, 31)
    timestamp = Time.zone.parse("2033-09-01 08:00:00")
    timed = create_entry(user: user, page_kind: "future", page_on: nil, occurs_on: boundary + 1, time_of_day: "10:00", created_at: timestamp)
    untimed = create_entry(user: user, page_kind: "future", page_on: nil, occurs_on: boundary + 1, time_of_day: nil, created_at: timestamp)
    overdue = create_entry(user: user, page_kind: "future", page_on: nil, occurs_on: boundary, time_of_day: "09:00")

    assert_equal [ overdue, timed, untimed ], user.entries.future_log.to_a
  end

  test "Collection pages contain only kept resident roots in capture order" do
    collection = collections(:camping)
    other_collection = users(:one).collections.create!(name: "Other")
    foreign_collection = users(:two).collections.create!(name: "Foreign")
    timestamp = Time.zone.parse("2033-10-01 08:00:00")
    later = create_entry(
      id: "0198f3b9-0000-7000-8000-000000000052",
      collection: collection,
      page_kind: "collection",
      page_on: nil,
      occurs_on: Date.new(2033, 10, 5),
      created_at: timestamp
    )
    earlier = create_entry(
      id: "0198f3b9-0000-7000-8000-000000000051",
      collection: collection,
      page_kind: "collection",
      page_on: nil,
      created_at: timestamp
    )
    child = create_entry(
      collection: collection,
      page_kind: "collection",
      page_on: nil,
      parent: earlier,
      kind: "note",
      state: nil
    )
    create_entry(collection: collection, page_kind: "collection", page_on: nil,
      deleted_at: timestamp)
    create_entry(collection: other_collection, page_kind: "collection", page_on: nil)
    create_entry(user: users(:two), collection: foreign_collection,
      page_kind: "collection", page_on: nil)
    daily_same_date = create_entry(page_kind: "daily", page_on: Date.new(2033, 10, 5),
      occurs_on: Date.new(2033, 10, 5))
    # Domain validation forbids a Daily row from carrying collection_id; the
    # scope still names page_kind so a stray column cannot grant membership.
    stray_page_kind = create_entry(page_kind: "daily", page_on: Date.new(2033, 10, 5),
      occurs_on: Date.new(2033, 10, 5))
    stray_page_kind.update_columns(collection_id: collection.id)

    roots = users(:one).entries.collection_page(collection.id)

    assert_not_includes roots, stray_page_kind,
      "page_kind must keep a Daily row off a Collection page even when collection_id is set"
    assert_not_includes roots, daily_same_date,
      "occurs_on must not grant Collection membership to a Daily resident"
    assert_not_includes roots, child
    assert_equal [ child ], earlier.children.kept.to_a
    assert_includes roots, later,
      "occurs_on must not exclude an entry resident on the Collection page"
    assert_equal [ earlier, later ], roots.to_a
  end

  test "open tasks return only kept open tasks in stable order" do
    user = users(:two)
    timestamp = Time.zone.parse("2034-01-01 08:00:00")
    later = create_entry(user: user, id: "0198f3b9-0000-7000-8000-000000000032", created_at: timestamp)
    earlier = create_entry(user: user, id: "0198f3b9-0000-7000-8000-000000000031", created_at: timestamp)
    create_entry(user: user, state: "done")
    create_entry(user: user, kind: "event", state: nil)
    create_entry(user: user, deleted_at: timestamp)

    assert_equal [ earlier, later ], user.entries.open_tasks.to_a
  end

  test "completes, strikes, and reopens only the allowed task states" do
    completed = create_entry
    completed.complete!
    assert_equal "done", completed.state
    assert_raises(Entry::LifecycleError) { completed.complete! }
    completed.reopen!
    assert_equal "open", completed.state

    struck = create_entry
    struck.strike!
    assert_equal "struck", struck.state
    struck.reopen!
    assert_equal "open", struck.state
    assert_raises(Entry::LifecycleError) { struck.reopen! }
  end

  test "rejects task lifecycle operations for non-tasks" do
    [ create_entry(kind: "event", state: nil), create_entry(kind: "note", state: nil) ].each do |record|
      assert_raises(Entry::LifecycleError) { record.complete! }
      assert_raises(Entry::LifecycleError) { record.strike! }
      assert_raises(Entry::LifecycleError) { record.reopen! }
    end
  end

  test "migrates append-only, clears calendar fields, and counts the chain" do
    task = create_entry(occurs_on: TODAY + 1, time_of_day: "09:30", parent: entries(:open_task))
    successor = task.move_to!(page_kind: "collection", page_on: nil, collection: collections(:camping), as_of: TODAY)

    assert_equal "migrated", task.reload.state
    assert_equal ">", task.glyph
    assert_equal "open", successor.state
    assert_equal task, successor.predecessor
    assert_equal successor, task.successor
    assert_equal collections(:camping), successor.collection
    assert_nil successor.parent
    assert_nil successor.occurs_on
    assert_nil successor.time_of_day
    assert_equal 1, successor.carried_count
    final = successor.move_to!(page_kind: "monthly_tasks", page_on: Date.new(2026, 10, 1), as_of: TODAY)
    assert_equal "migrated", successor.reload.state
    assert_equal 2, final.carried_count
    assert_not_includes users(:one).entries.monthly_tasks(Date.new(2026, 9, 15)), successor
    assert_raises(Entry::LifecycleError) do
      task.move_to!(page_kind: "monthly_tasks", page_on: Date.new(2026, 11, 1), as_of: TODAY)
    end
  end

  test "the unique index prevents a migration chain from becoming a tree" do
    task = create_entry
    task.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)

    assert_raises(ActiveRecord::RecordNotUnique) do
      create_entry(predecessor: task)
    end
  end

  test "schedules append-only while preserving capture date and time" do
    task = create_entry(time_of_day: "14:30", parent: entries(:open_task))
    successor = task.move_to!(page_kind: "future", page_on: nil, occurs_on: Date.new(2026, 10, 1), as_of: TODAY)

    assert_equal "migrated", task.reload.state
    assert_equal "<", task.glyph
    assert_nil successor.page_on
    assert_equal "14:30", successor.time_of_day
    assert_equal Date.new(2026, 10, 1), successor.occurs_on
    assert_nil successor.collection
    assert_nil successor.parent
    assert_includes users(:one).entries.future_log, successor
  end

  test "rejects migration and scheduling outside the open state" do
    done = create_entry(state: "done")
    migrated = create_entry(state: "migrated")

    [ done, migrated ].each do |record|
      assert_raises(Entry::LifecycleError) do
        record.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
      end
    end
  end

  test "rejects every task transition not allowed by the lifecycle table" do
    disallowed_transitions = {
      "done" => %i[complete! strike!],
      "struck" => %i[complete! strike! move_to!],
      "migrated" => %i[complete! strike! reopen! move_to!]
    }

    disallowed_transitions.each do |state, operations|
      operations.each do |operation|
        task = create_entry(state: state)

        assert_raises(Entry::LifecycleError, "#{operation} from #{state}") do
          perform_lifecycle_operation(task, operation)
        end
      end
    end
  end

  test "derives every journal glyph from entry state and migration destination" do
    open = create_entry
    struck = create_entry(state: "struck")
    done = create_entry(state: "done")
    migrated = create_entry
    migrated.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
    scheduled = create_entry
    scheduled.move_to!(page_kind: "future", page_on: nil, occurs_on: TODAY.next_month, as_of: TODAY)
    event = create_entry(kind: "event", state: nil)
    note = create_entry(kind: "note", state: nil)

    assert_equal [ "•", "•", "x", ">", "<", "○", "–" ],
      [ open, struck, done, migrated, scheduled, event, note ].map(&:glyph)
  end

  test "priority transitions change only priority and updated_at" do
    task = create_entry(
      text: "Choose this work",
      tags: %w[reflection],
      occurs_on: TODAY + 2.days,
      time_of_day: "09:30",
      hlc: "2026-08-24T09:30:00.000Z-0001-test",
      server_seq: 41
    )
    original = task.attributes.except("priority", "updated_at")

    task.mark_priority!

    assert_predicate task.reload, :priority?
    assert_equal original, task.attributes.except("priority", "updated_at")

    task.clear_priority!

    assert_not task.reload.priority?
    assert_equal original, task.attributes.except("priority", "updated_at")
  end

  test "priority transitions reject mismatched settled moved and deleted tasks" do
    already_marked = create_entry(priority: true)
    done = create_entry(state: "done")
    moved = create_entry
    moved.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
    deleted = create_entry
    deleted.soft_delete!

    [
      [ already_marked, :mark_priority! ],
      [ create_entry, :clear_priority! ],
      [ done, :mark_priority! ],
      [ moved, :mark_priority! ],
      [ deleted, :mark_priority! ]
    ].each do |task, command|
      snapshot = task.reload.attributes

      assert_raises(Entry::LifecycleError) { task.public_send(command) }
      assert_equal snapshot, task.reload.attributes
    end
  end

  test "soft deletion removes an entry from every log without deleting its row" do
    task = create_entry(page_on: TODAY, occurs_on: TODAY + 1)
    deleted_at = Time.zone.parse("2026-08-24 14:00:00")
    task.soft_delete!(at: deleted_at)
    entries = users(:one).entries

    assert_equal deleted_at, task.reload.deleted_at
    assert_equal task, Entry.find(task.id)
    assert_not_includes Entry.kept, task
    assert_not_includes entries.daily_log(TODAY), task
    assert_not_includes entries.monthly_calendar(TODAY), task
    assert_not_includes entries.monthly_tasks(TODAY), task
    assert_not_includes entries.future_log, task
    assert_not_includes entries.open_tasks, task
  end

  test "children stay reachable and ordered when a parent is soft-deleted" do
    parent = create_entry
    timestamp = Time.zone.parse("2026-08-24 15:00:00")
    later = create_entry(
      id: "0198f3b9-0000-7000-8000-000000000042",
      kind: "note",
      state: nil,
      parent: parent,
      created_at: timestamp
    )
    earlier = create_entry(
      id: "0198f3b9-0000-7000-8000-000000000041",
      kind: "note",
      state: nil,
      parent: parent,
      created_at: timestamp
    )

    parent.soft_delete!(at: timestamp)

    assert_equal [ earlier, later ], parent.children.to_a
    assert_predicate earlier.reload, :persisted?
    assert_not_includes users(:one).entries.daily_log(parent.page_on), earlier
  end

  test "fixture ids survive and generated ids are UUIDv7" do
    assert_equal "0198f3b9-0000-7000-8000-000000000002", entries(:open_task).id

    assert_uuid_v7 create_entry.id
  end

  private

  def entry(overrides = {})
    Entry.new(entry_attributes.merge(overrides))
  end

  def create_entry(overrides = {})
    Entry.create!(entry_attributes.merge(overrides))
  end

  def entry_attributes
    {
      user: users(:one),
      kind: "task",
      state: "open",
      text: "A task",
      priority: false,
      tags: [],
      page_kind: "daily",
      page_on: TODAY
    }
  end

  def assert_invalid(record, attribute)
    assert_not record.valid?
    assert_not_empty record.errors[attribute]
  end

  def capture(line, **overrides)
    Entry.capture!(
      line,
      user: users(:one),
      today: TODAY,
      as_of: TODAY,
      page_kind: "daily",
      page_on: TODAY,
      **overrides
    )
  end

  def perform_lifecycle_operation(task, operation)
    case operation
    when :move_to!
      task.move_to!(page_kind: "monthly_tasks", page_on: TODAY.next_month.beginning_of_month, as_of: TODAY)
    else
      task.public_send(operation)
    end
  end
end
