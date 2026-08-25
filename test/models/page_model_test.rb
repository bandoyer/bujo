require "test_helper"

# Exercises page residency as a domain contract rather than as a rendering
# convenience. Dates in these tests are injected so advancing the real clock
# can never change whether an existing row is valid.
class PageModelTest < ActiveSupport::TestCase
  AS_OF = Date.new(2026, 8, 25)
  PAGE_ON = AS_OF.beginning_of_month

  test "accepts the complete root page grammar" do
    valid_roots = [
      attributes(page_kind: "daily", page_on: AS_OF, kind: "task", state: "open"),
      attributes(page_kind: "daily", page_on: AS_OF, kind: "event", state: nil),
      attributes(page_kind: "daily", page_on: AS_OF, kind: "note", state: nil),
      attributes(page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF, kind: "task", state: "open"),
      attributes(page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF, kind: "event", state: nil),
      attributes(page_kind: "monthly_tasks", page_on: PAGE_ON, kind: "task", state: "open"),
      attributes(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month, kind: "task", state: "open"),
      attributes(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month, kind: "event", state: nil),
      attributes(page_kind: "collection", page_on: nil, collection: collections(:camping), kind: "task", state: "open"),
      attributes(page_kind: "collection", page_on: nil, collection: collections(:camping), kind: "event", state: nil),
      attributes(page_kind: "collection", page_on: nil, collection: collections(:camping), kind: "note", state: nil)
    ]

    valid_roots.each { |root_attributes| assert_predicate Entry.new(root_attributes), :valid? }
  end

  test "rejects every incompatible root kind" do
    invalid_roots = [
      attributes(page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF, kind: "note", state: nil),
      attributes(page_kind: "monthly_tasks", page_on: PAGE_ON, kind: "event", state: nil),
      attributes(page_kind: "monthly_tasks", page_on: PAGE_ON, kind: "note", state: nil),
      attributes(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month, kind: "note", state: nil)
    ]

    invalid_roots.each { |root_attributes| assert_invalid Entry.new(root_attributes), :kind }
  end

  test "validates each page date and collection shape" do
    assert_invalid build(page_kind: "agenda"), :page_kind
    assert_invalid build(page_kind: "daily", page_on: nil), :page_on
    assert_invalid build(page_kind: "daily", page_on: AS_OF, collection: collections(:camping)), :collection
    assert_invalid build(page_kind: "monthly_tasks", page_on: AS_OF), :page_on
    assert_invalid build(page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: nil), :occurs_on
    assert_invalid build(page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF.next_month), :occurs_on
    assert_invalid build(page_kind: "future", page_on: PAGE_ON, occurs_on: AS_OF.next_month), :page_on
    assert_invalid build(page_kind: "future", page_on: nil, occurs_on: nil), :occurs_on
    assert_invalid build(page_kind: "collection", page_on: nil, collection: nil), :collection
    foreign_collection = users(:two).collections.create!(name: "Foreign")
    assert_invalid build(page_kind: "collection", page_on: nil, collection: foreign_collection), :collection
  end

  test "allows every child kind only when the entire placement matches its parent" do
    parent = create(page_kind: "monthly_tasks", page_on: PAGE_ON)

    %w[task event note].each do |kind|
      state = kind == "task" ? "open" : nil
      assert_predicate build(page_kind: parent.page_kind, page_on: parent.page_on, parent: parent, kind: kind, state: state), :valid?
    end

    assert_invalid build(page_kind: "daily", page_on: PAGE_ON, parent: parent), :page_kind
    assert_invalid build(page_kind: parent.page_kind, page_on: PAGE_ON.next_month, parent: parent), :page_on
    collection_parent = create(page_kind: "collection", page_on: nil, collection: collections(:camping))
    assert_invalid build(page_kind: "collection", page_on: nil, collection: nil, parent: collection_parent), :collection
  end

  test "capture places parser output and enforces temporal admission" do
    daily = Entry.capture!(
      "call tomorrow", user: users(:one), today: AS_OF, as_of: AS_OF,
      page_kind: "daily", page_on: AS_OF
    )
    monthly = Entry.capture!(
      "monthly inventory tomorrow", user: users(:one), today: AS_OF, as_of: AS_OF,
      page_kind: "monthly_tasks", page_on: PAGE_ON
    )
    calendar = Entry.capture!(
      "o appointment tomorrow", user: users(:one), today: AS_OF, as_of: AS_OF,
      page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF
    )
    future = Entry.capture!(
      "o launch tomorrow", user: users(:one), today: AS_OF.next_month, as_of: AS_OF,
      page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month
    )

    assert_equal [ "daily", AS_OF, AS_OF.next_day ], [ daily.page_kind, daily.page_on, daily.occurs_on ]
    assert_equal [ "monthly_tasks", PAGE_ON, AS_OF.next_day ], [ monthly.page_kind, monthly.page_on, monthly.occurs_on ]
    assert_equal AS_OF, calendar.occurs_on
    assert_equal AS_OF.next_month, future.occurs_on

    assert_capture_refused(page_kind: "daily", page_on: AS_OF.next_day, today: AS_OF.next_day)
    assert_capture_refused(page_kind: "monthly_tasks", page_on: PAGE_ON.next_month, today: AS_OF)
    assert_capture_refused(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_day, today: AS_OF.next_day)
    next_month = AS_OF.next_month.beginning_of_month
    assert_capture_refused(page_kind: "future", page_on: nil, occurs_on: next_month, today: next_month, as_of: next_month)
  end

  # The reading screens offer a writing affordance only where this predicate
  # says a page is open, so a disagreement between it and the command would
  # either hide a legal gesture or show one the server then refuses.
  test "the affordance predicate and the capture guard answer as one rule" do
    next_month = AS_OF.next_month.beginning_of_month
    placements = {
      "today's Daily page" => [ true, { page_kind: "daily", page_on: AS_OF } ],
      "a future Daily page" => [ false, { page_kind: "daily", page_on: AS_OF.next_day } ],
      "a Daily page with no date" => [ false, { page_kind: "daily", page_on: nil } ],
      "the current Tasks page" => [ true, { page_kind: "monthly_tasks", page_on: PAGE_ON } ],
      "a future Tasks page" => [ false, { page_kind: "monthly_tasks", page_on: PAGE_ON.next_month } ],
      "a Tasks page with no date" => [ false, { page_kind: "monthly_tasks", page_on: nil } ],
      "the current Calendar page" => [ true, { page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF } ],
      "a future Calendar page" => [ false, { page_kind: "monthly_calendar", page_on: PAGE_ON.next_month, occurs_on: next_month } ],
      "a Future month after this one" => [ true, { page_kind: "future", page_on: nil, occurs_on: next_month } ],
      "a Future date still inside this month" => [ false, { page_kind: "future", page_on: nil, occurs_on: AS_OF.next_day } ],
      "the last day of this month on the Future Log" => [ false, { page_kind: "future", page_on: nil, occurs_on: AS_OF.end_of_month } ],
      "a Future page with no date" => [ false, { page_kind: "future", page_on: nil, occurs_on: nil } ],
      "a Collection page" => [ true, { page_kind: "collection", page_on: nil, collection: collections(:camping) } ]
    }

    placements.each do |page, (admitted, placement)|
      assert_equal admitted, Entry.capture_admitted?(as_of: AS_OF, **placement.except(:collection)),
        "capture_admitted? misjudged #{page}"

      if admitted
        assert Entry.capture!("check", user: users(:one), today: AS_OF, as_of: AS_OF, **placement),
          "capture! refused #{page}, which the predicate admitted"
      else
        assert_capture_refused(today: AS_OF, **placement)
      end
    end
  end

  test "old Future residents remain structurally valid when their month arrives" do
    resident = create(page_kind: "future", page_on: nil, occurs_on: AS_OF)

    assert_predicate resident, :valid?
  end

  test "persisted placement rejects assignment and mass assignment without changing the row" do
    entry = create(page_kind: "daily", page_on: AS_OF)
    original = [ entry.page_kind, entry.page_on, entry.collection_id ]

    assert_not entry.update(page_kind: "future", page_on: nil)
    assert_not_empty entry.errors[:page_kind]
    assert_not_empty entry.errors[:page_on]
    assert_equal original, entry.reload.values_at(:page_kind, :page_on, :collection_id)

    assert_raises(ActiveRecord::RecordInvalid) do
      entry.update!(page_kind: "collection", page_on: nil, collection: collections(:camping))
    end
    assert_equal original, entry.reload.values_at(:page_kind, :page_on, :collection_id)
  end

  test "page scopes return only kept roots in residency order without date leakage" do
    user = users(:two)
    timestamp = Time.zone.parse("2030-01-01 10:00:00")
    daily = create(user: user, page_kind: "daily", page_on: AS_OF, occurs_on: AS_OF.next_month, created_at: timestamp)
    calendar = create(user: user, page_kind: "monthly_calendar", page_on: PAGE_ON, occurs_on: AS_OF, kind: "event", state: nil, created_at: timestamp)
    tasks = create(user: user, page_kind: "monthly_tasks", page_on: PAGE_ON, created_at: timestamp)
    future = create(user: user, page_kind: "future", page_on: nil, occurs_on: AS_OF, created_at: timestamp)
    child = create(user: user, page_kind: "daily", page_on: AS_OF, parent: daily)
    deleted = create(user: user, page_kind: "daily", page_on: AS_OF)
    deleted.soft_delete!

    assert_equal [ daily ], user.entries.daily_log(AS_OF).to_a
    assert_equal [ calendar ], user.entries.monthly_calendar(PAGE_ON).to_a
    assert_equal [ tasks ], user.entries.monthly_tasks(PAGE_ON).to_a
    assert_equal [ future ], user.entries.future_log.to_a
    assert_not_includes user.entries.daily_log(AS_OF), calendar
    assert_not_includes user.entries.daily_log(AS_OF.next_month), daily
    assert_not_includes user.entries.daily_log(AS_OF), child
  end

  test "movement is kind-aware append-only and glyph direction follows destination page" do
    task = create(page_kind: "daily", page_on: AS_OF, time_of_day: "09:30")
    monthly_successor = task.move_to!(
      page_kind: "monthly_tasks", page_on: PAGE_ON.next_month, as_of: AS_OF
    )
    event = create(page_kind: "daily", page_on: AS_OF, kind: "event", state: nil, time_of_day: "10:00")
    future_successor = event.move_to!(
      page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month, as_of: AS_OF
    )
    note = create(page_kind: "daily", page_on: AS_OF, kind: "note", state: nil)
    collection_successor = note.move_to!(
      page_kind: "collection", page_on: nil, collection: collections(:camping), as_of: AS_OF
    )

    assert_equal [ "migrated", ">", "open", nil ],
      [ task.reload.state, task.glyph, monthly_successor.state, monthly_successor.time_of_day ]
    assert_equal [ nil, "<", nil, "10:00" ],
      [ event.reload.state, event.glyph, future_successor.state, future_successor.time_of_day ]
    assert_equal [ nil, ">", nil, nil ],
      [ note.reload.state, note.glyph, collection_successor.state, collection_successor.occurs_on ]
    assert_equal [ task, event, note ],
      [ monthly_successor.predecessor, future_successor.predecessor, collection_successor.predecessor ]
  end

  test "movement refuses invalid lifecycle, a second successor, and same-month Future dates" do
    %w[done struck migrated].each do |state|
      task = create(state: state)
      assert_raises(Entry::LifecycleError) do
        task.move_to!(page_kind: "monthly_tasks", page_on: PAGE_ON.next_month, as_of: AS_OF)
      end
    end

    moved_event = create(kind: "event", state: nil)
    moved_event.move_to!(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month, as_of: AS_OF)
    assert_raises(Entry::LifecycleError) do
      moved_event.move_to!(page_kind: "future", page_on: nil, occurs_on: AS_OF.next_month.next_day, as_of: AS_OF)
    end

    assert_raises(Entry::LifecycleError) do
      create.move_to!(page_kind: "future", page_on: nil, occurs_on: AS_OF.end_of_month, as_of: AS_OF)
    end
  end

  private

  def attributes(overrides = {})
    {
      user: users(:one), kind: "task", state: "open", text: "A resident",
      priority: false, tags: [], page_kind: "daily", page_on: AS_OF
    }.merge(overrides)
  end

  def build(overrides = {})
    Entry.new(attributes(overrides))
  end

  def create(overrides = {})
    Entry.create!(attributes(overrides))
  end

  def assert_invalid(record, attribute)
    assert_not record.valid?
    assert_not_empty record.errors[attribute]
  end

  def assert_capture_refused(as_of: AS_OF, **placement)
    assert_raises(ActiveRecord::RecordInvalid) do
      Entry.capture!("refused", user: users(:one), as_of: as_of, **placement)
    end
  end
end
