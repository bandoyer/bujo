require "test_helper"

# Exercises the deliberate exact-Topic gesture that appends an Entry successor
# to a Custom Collection while preserving the source page and predecessor.
class MoveToCollectionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @destination = @user.collections.create!(name: "Camping Move Target")
    @foreign_destination = users(:two).collections.create!(name: "Ignored Foreign Topic")
    sign_in_as @user
  end

  test "every structurally valid root kind moves from each admitted source page" do
    valid_root_sources.each do |page_kind, kind|
      entry = create_source_entry(page_kind: page_kind, kind: kind)

      assert_difference -> { Entry.count }, 1 do
        post_move(entry, topic: "  CAMPING MOVE TARGET  ")
      end

      assert_redirected_to source_path(entry)
      assert_nil flash[:alert]
      successor = entry.reload.successor
      assert_equal [ "collection", nil, @destination.id, nil, nil, nil ],
        successor.values_at(:page_kind, :page_on, :collection_id, :parent_id, :occurs_on, :time_of_day)
      assert_equal [ entry.kind, entry.text, entry.priority, entry.tags, entry.user ],
        [ successor.kind, successor.text, successor.priority, successor.tags, successor.user ]
      if entry.kind == "task"
        assert_equal "migrated", entry.state
      else
        assert_nil entry.state
      end
      assert_nil successor.hlc
      assert_nil successor.server_seq
      assert_nil @destination.reload.index_position
    end
  end

  test "a nested dated note moves to one fresh root without carrying dates or children" do
    parent = create_source_entry(page_kind: "daily", kind: "task")
    predecessor = create_source_entry(
      page_kind: "daily", kind: "note", parent: parent,
      text: "call the ranger", priority: true, tags: %w[camping phone],
      occurs_on: Date.new(2026, 8, 24), time_of_day: "17:00"
    )
    child = create_source_entry(page_kind: "daily", kind: "note", parent: predecessor,
      text: "ask about firewood")
    predecessor.update_columns(hlc: "1710000000000:2:qa", server_seq: 73)
    predecessor_attributes = predecessor.attributes
    child_attributes = child.attributes

    post_move(predecessor, topic: @destination.name)

    assert_redirected_to daily_log_path(date: "2026-08-24")
    successor = predecessor.reload.successor
    assert_not_nil successor, "a nested note must append a Collection successor rather than fail the move"
    assert_uuid_v7 successor.id
    refute_equal predecessor.id, successor.id
    assert_equal predecessor.id, successor.migrated_from_id
    assert_nil successor.parent_id,
      "the Collection successor is a new root; it must not inherit the predecessor's parent"
    assert_equal [ "note", nil, "call the ranger", true, %w[camping phone], @user ],
      [ successor.kind, successor.state, successor.text, successor.priority, successor.tags, successor.user ]
    assert_equal [ "collection", nil, @destination.id, nil, nil ],
      successor.values_at(:page_kind, :page_on, :collection_id, :occurs_on, :time_of_day)
    assert_equal Date.new(2026, 8, 24), predecessor.occurs_on,
      "the predecessor keeps its historical occurs_on"
    assert_equal predecessor_attributes, predecessor.reload.attributes
    assert_equal child_attributes, child.reload.attributes
    assert_nil child.collection_id
    assert_equal predecessor.id, child.parent_id
    assert_equal ">", predecessor.glyph
    assert_equal "–", successor.glyph
    assert_equal "1710000000000:2:qa", predecessor.hlc
    assert_equal 73, predecessor.server_seq
    assert_nil successor.hlc
    assert_nil successor.server_seq
  end

  test "destination lookup stays inside the current user's kept Collections" do
    users(:two).collections.create!(name: "Shared Topic")
    mine = @user.collections.create!(name: "Shared Topic")
    entry = create_source_entry(page_kind: "daily", kind: "note")

    post_move(entry, topic: "Shared Topic")

    successor = entry.reload.successor
    assert_not_nil successor,
      "Move to Collection must resolve the Topic inside the current user's journal"
    assert_equal mine, successor.collection,
      "Move to Collection must resolve the Topic inside the current user's journal"
  end

  test "indexed and unindexed exact Topics both resolve without changing registration" do
    indexed = @user.collections.create!(name: "Reading List")
    indexed.entries.create!(
      user: @user, kind: "note", state: nil, text: "seed", tags: [],
      page_kind: "collection", page_on: nil
    )
    indexed.register!

    [ @destination, indexed ].each do |collection|
      task = create_source_entry(page_kind: "daily", kind: "task")
      original_collection = collection.attributes

      post_move(task, topic: "  #{collection.name.swapcase}  ")

      assert_redirected_to daily_log_path(date: "2026-08-24")
      assert_equal collection, task.reload.successor.collection
      assert_equal original_collection, collection.reload.attributes
    end
    assert_nil @destination.reload.index_position
    assert_not_nil indexed.reload.index_position
  end

  test "every exact-Topic miss refuses identically without writing" do
    deleted = @user.collections.create!(name: "Deleted Camp")
    deleted.soft_delete_if_unused!
    foreign = users(:two).collections.create!(name: "Foreign Camp")
    misses = [ "", "Camping", "Trip", "Camp Trip", deleted.name, foreign.name, "camping trips" ]

    misses.each do |topic|
      entry = create_source_entry(page_kind: "daily", kind: "note")
      original_journal = journal_snapshot
      original_collections = collection_snapshot

      assert_no_difference -> { Entry.unscoped.count } do
        post_move(entry, topic: topic)
      end

      assert_redirected_to daily_log_path(date: "2026-08-24")
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original_journal, journal_snapshot
      assert_equal original_collections, collection_snapshot
      assert_nil entry.reload.successor
    end
  end

  test "a second move is refused without changing either side" do
    entry = create_source_entry(page_kind: "daily", kind: "event")
    post_move(entry, topic: @destination.name)
    predecessor_attributes = entry.reload.attributes
    successor_attributes = entry.successor.attributes
    original_journal = journal_snapshot

    assert_no_difference -> { Entry.count } do
      post_move(entry, topic: @destination.name)
    end

    assert_redirected_to daily_log_path(date: "2026-08-24")
    assert_equal "That entry can't do that.", flash[:alert]
    assert_equal predecessor_attributes, entry.reload.attributes
    assert_equal successor_attributes, entry.successor.reload.attributes
    assert_equal original_journal, journal_snapshot
  end

  test "each source page is retained after a destination refusal" do
    %w[daily monthly_calendar monthly_tasks].each do |page_kind|
      entry = create_source_entry(page_kind: page_kind, kind: "task")
      original_attributes = entry.attributes

      post_move(entry, topic: "Unknown Topic")

      assert_redirected_to source_path(entry)
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original_attributes, entry.reload.attributes
      assert_nil entry.successor
      follow_redirect!
    end
  end

  test "ineligible lifecycle and residency shapes render no control and refuse crafted moves" do
    ineligible_entries.each do |entry|
      get rendering_path(entry)
      assert_select "#entry_#{entry.id} form[action='#{move_to_collection_entry_path(entry)}']", count: 0
      original_journal = journal_snapshot

      assert_no_difference -> { Entry.count } do
        post_move(entry, topic: @destination.name)
      end

      assert_redirected_to source_path(entry)
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original_journal, journal_snapshot
    end
  end

  test "eligible task event and note rows render movement controls with per-entry labels" do
    eligible_entries.each do |entry|
      get source_path(entry)
      topic_field_id = "move_topic_#{entry.id}"

      assert_select "#entry_#{entry.id} > .entry__toggle", count: 1
      assert_select "#entry_#{entry.id} form[action='#{move_to_collection_entry_path(entry)}']", count: 1
      assert_select "#entry_#{entry.id} input##{topic_field_id}[name='topic'][autocomplete='off']", count: 1
      assert_select "#entry_#{entry.id} label[for='#{topic_field_id}']", text: "Exact Topic", count: 1
    end
  end

  test "destination meta names a Collection while dated successors keep their date" do
    collection_entry = create_source_entry(page_kind: "daily", kind: "note", text: "collection meta")
    monthly_entry = create_source_entry(page_kind: "daily", kind: "task", text: "monthly meta")
    future_entry = create_source_entry(page_kind: "daily", kind: "event", text: "future meta")
    post_move(collection_entry, topic: @destination.name)
    monthly_entry.move_to!(page_kind: "monthly_tasks", page_on: Date.new(2026, 9, 1), as_of: Date.new(2026, 8, 25))
    future_entry.move_to!(page_kind: "future", page_on: nil, occurs_on: Date.new(2026, 10, 4),
      as_of: Date.new(2026, 8, 25))

    get daily_log_path(date: "2026-08-24")

    assert_select "#entry_#{collection_entry.id} .entry__meta",
      { text: /→ Camping Move Target/ },
      "a Collection successor must name the Topic, not a date"
    assert_select "#entry_#{monthly_entry.id} .entry__meta", text: /→ SEP 1/
    assert_select "#entry_#{future_entry.id} .entry__meta", text: /→ OCT 4/
  end

  private

  def valid_root_sources
    [
      [ "daily", "task" ], [ "daily", "event" ], [ "daily", "note" ],
      [ "monthly_calendar", "task" ], [ "monthly_calendar", "event" ],
      [ "monthly_tasks", "task" ]
    ]
  end

  def eligible_entries
    [
      create_source_entry(page_kind: "daily", kind: "task"),
      create_source_entry(page_kind: "daily", kind: "event"),
      create_source_entry(page_kind: "daily", kind: "note"),
      create_source_entry(page_kind: "monthly_calendar", kind: "event"),
      create_source_entry(page_kind: "monthly_tasks", kind: "task")
    ]
  end

  def ineligible_entries
    done = create_source_entry(page_kind: "daily", kind: "task", state: "done")
    struck = create_source_entry(page_kind: "daily", kind: "task", state: "struck")
    migrated = create_source_entry(page_kind: "daily", kind: "task", state: "migrated")
    moved_event = create_source_entry(page_kind: "daily", kind: "event")
    moved_event.move_to!(page_kind: "future", page_on: nil, occurs_on: Date.new(2026, 10, 1),
      as_of: Date.new(2026, 8, 25))
    moved_note = create_source_entry(page_kind: "daily", kind: "note")
    moved_note.move_to!(page_kind: "collection", page_on: nil, collection: @destination,
      as_of: Date.new(2026, 8, 25))
    future = create_source_entry(page_kind: "future", kind: "task")
    collection = create_source_entry(page_kind: "collection", kind: "task")
    [ done, struck, migrated, moved_event, moved_note, future, collection ]
  end

  def create_source_entry(page_kind:, kind:, parent: nil, state: :default,
    text: nil, priority: false, tags: [], occurs_on: nil, time_of_day: nil)
    page_on, required_occurrence, collection = placement_for(page_kind)
    @user.entries.create!(
      kind: kind,
      state: state == :default ? ("open" if kind == "task") : state,
      text: text || "#{page_kind} #{kind} #{SecureRandom.hex(3)}",
      priority: priority,
      tags: tags,
      page_kind: page_kind,
      page_on: page_on,
      collection: collection,
      occurs_on: occurs_on || required_occurrence,
      time_of_day: time_of_day,
      parent: parent
    )
  end

  def placement_for(page_kind)
    case page_kind
    when "daily" then [ Date.new(2026, 8, 24), nil, nil ]
    when "monthly_calendar" then [ Date.new(2026, 8, 1), Date.new(2026, 8, 24), nil ]
    when "monthly_tasks" then [ Date.new(2026, 8, 1), nil, nil ]
    when "future" then [ nil, Date.new(2026, 10, 1), nil ]
    when "collection" then [ nil, nil, @destination ]
    end
  end

  def post_move(entry, topic:)
    post move_to_collection_entry_path(entry), params: source_params(entry).merge(
      topic: topic,
      collection_id: @foreign_destination.id
    )
  end

  def source_params(entry)
    case entry.page_kind
    when "monthly_calendar"
      { viewed_on: "2026-08-01", return_to: "monthly_calendar" }
    when "monthly_tasks"
      { viewed_on: "2026-08-01", return_to: "monthly_tasks" }
    else
      { viewed_on: "2026-08-24" }
    end
  end

  def source_path(entry)
    case entry.page_kind
    when "monthly_calendar" then monthly_log_path(month: "2026-08")
    when "monthly_tasks" then monthly_log_path(month: "2026-08", view: "tasks")
    when "collection" then collection_path(@destination)
    when "future" then daily_log_path(date: "2026-08-24")
    else daily_log_path(date: "2026-08-24")
    end
  end

  def rendering_path(entry)
    entry.page_kind == "future" ? future_log_path : source_path(entry)
  end

  def journal_snapshot
    @user.entries.order(:id).map(&:attributes)
  end

  def collection_snapshot
    Collection.order(:id).map(&:attributes)
  end
end
