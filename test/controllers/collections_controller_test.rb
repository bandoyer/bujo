require "test_helper"

# Pins the reader-facing gestures for deliberate Custom Collections without
# duplicating the lifecycle rules already owned by Collection and Entry.
class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "Index is authenticated and lists only registered current-user Topics in manual order" do
    sign_out
    get journal_index_path
    assert_redirected_to new_session_path

    sign_in_as @user
    first = create_filled_collection("First registered")
    second = create_filled_collection("Second registered")
    unindexed = @user.collections.create!(name: "Known but unindexed")
    foreign = users(:two).collections.create!(name: "Foreign registered")
    # A phase-2 pull can deliver a tombstone that still carries its rank;
    # the Index must not resurrect it.
    deleted = create_filled_collection("Deleted registered")
    first.update_column(:index_position, 2)
    second.update_column(:index_position, 5)
    foreign.update_column(:index_position, 1)
    deleted.update_columns(index_position: 3, deleted_at: Time.zone.parse("2026-08-25 13:00:00"))

    get journal_index_path

    assert_response :success
    assert_select "h1:first-of-type", text: "Index"
    assert_select "a", { text: deleted.name, count: 0 },
      "the Index must not list a soft-deleted Collection that retained its rank"
    assert_select ".collection-index__topics a", count: 2
    document = Nokogiri::HTML(response.body)
    assert_equal [ "First registered", "Second registered" ],
      document.css(".collection-index__topics a").map { |link| link.text.strip }
    assert_select "a", text: unindexed.name, count: 0
    assert_select "a", text: foreign.name, count: 0
    assert_select ".tab-bar__item[aria-current='page']", text: "Index", count: 1
  end

  test "empty Index does not disclose unindexed Collections" do
    unindexed = @user.collections.create!(name: "Secret unindexed Topic")

    get journal_index_path

    assert_response :success
    assert_select ".collection-index__empty", text: "Nothing indexed yet."
    assert_select "a", text: unindexed.name, count: 0
    assert_select "#new_collection_panel[hidden]"
    assert_select "#locate_collection_panel[hidden]"
    assert_select "input[name='topic'][autocomplete='off']"
  end

  test "create trims a Topic and opens its stable unindexed page" do
    assert_difference -> { @user.collections.count }, 1 do
      post collections_path, params: {
        collection: { name: "  Camping   Notes  ", index_position: 99 }
      }
    end

    collection = @user.collections.find_by!(name: "Camping   Notes")
    assert_nil collection.index_position
    assert_redirected_to collection_path(collection)
  end

  test "create refusal keeps the New Collection form open and preserves the submitted Topic" do
    [ "   ", "camping trip" ].each do |topic|
      assert_no_difference -> { @user.collections.count } do
        post collections_path, params: { collection: { name: topic } }
      end

      assert_response :unprocessable_entity
      assert_select "#new_collection_toggle[aria-expanded='true']"
      assert_select "#new_collection_panel:not([hidden])"
      assert_select "input[name='collection[name]'][value=?]", topic
      assert_select ".form-errors"
    end
  end

  test "locate redirects exact indexed and unindexed Topics to canonical URLs" do
    indexed = create_filled_collection("Reading List")
    indexed.register!
    unindexed = @user.collections.create!(name: "Garden Plans")

    post locate_collections_path, params: { topic: "  reading list  " }
    assert_redirected_to collection_path(indexed)

    post locate_collections_path, params: { topic: "GARDEN PLANS" }
    assert_redirected_to collection_path(unindexed)
  end

  test "all exact-Topic misses return one indistinguishable refusal without candidates" do
    renamed = @user.collections.create!(name: "Current Name")
    deleted = @user.collections.create!(name: "Deleted Topic")
    deleted.soft_delete_if_unused!
    users(:two).collections.create!(name: "Foreign Topic")
    misses = [ "", "Camping", "Old Name", deleted.name, "Foreign Topic" ]
    bodies = misses.map do |topic|
      post locate_collections_path, params: { topic: topic }
      assert_response :unprocessable_entity
      assert_select "#locate_collection_toggle[aria-expanded='true']"
      assert_select "[role='alert']", text: "No Collection with that exact Topic."
      assert_select ".collection-index__topics", count: 0
      response.body
    end

    assert_equal 1, bodies.uniq.size
    assert_not_includes bodies.first, renamed.name
    assert_not_includes bodies.first, deleted.name
    assert_not_includes bodies.first, "Foreign Topic"
  end

  test "Collection page renders kept roots recursively without action controls" do
    collection = @user.collections.create!(name: "Rendered Topic")
    timestamp = Time.zone.parse("2026-08-25 15:00:00")
    later = create_collection_entry(collection, text: "Later root", occurs_on: Date.new(2030, 1, 2),
      created_at: timestamp, id: "0198f3b9-0000-7000-8000-000000000072")
    earlier = create_collection_entry(collection, text: "Earlier root", created_at: timestamp,
      id: "0198f3b9-0000-7000-8000-000000000071")
    child = create_collection_entry(collection, text: "Kept child", parent: earlier,
      kind: "note", state: nil)
    deleted = create_collection_entry(collection, text: "Deleted root")
    deleted.soft_delete!

    get collection_path(collection)

    assert_response :success
    assert_select "h1", text: collection.name
    assert_select ".collection-page__context", text: "Collection · not indexed"
    assert_select ".entry-list > #entry_#{earlier.id}"
    assert_select ".entry-list > #entry_#{later.id}"
    assert_select "#entry_#{earlier.id} #entry_#{child.id}"
    assert_select "#entry_#{deleted.id}", count: 0
    assert_select ".entry__action-strip", count: 0
    assert_select ".entry__toggle", count: 0
    assert_select "form[action*='/complete']", count: 0
    assert_select ".tab-bar__item[aria-current='page']", text: "Index", count: 1
  end

  test "empty and filled Collection controls mirror registration and deletion guards" do
    empty = @user.collections.create!(name: "Empty Topic")
    get collection_path(empty)
    assert_select ".entry-list__empty", text: /Nothing logged yet.*Add a first entry before indexing/m
    assert_select "form[action='#{register_collection_path(empty)}']", count: 0
    assert_select "form[action='#{collection_path(empty)}'][data-turbo-confirm]", count: 1

    create_collection_entry(empty)
    get collection_path(empty)
    assert_select "form[action='#{register_collection_path(empty)}']", count: 1
    assert_select "form[action='#{collection_path(empty)}'][data-turbo-confirm]", count: 0

    empty.register!
    get collection_path(empty)
    assert_select ".collection-page__context", text: "Collection · indexed"
    assert_select "form[action='#{registration_collection_path(empty)}']", count: 1
  end

  test "rename register and unindex stay on the Collection and preserve manual position" do
    collection = create_filled_collection("Lifecycle Topic")

    post register_collection_path(collection)
    assert_redirected_to collection_path(collection)
    position = collection.reload.index_position
    assert_not_nil position

    patch collection_path(collection), params: { collection: { name: " Renamed Topic ", index_position: 1 } }
    assert_redirected_to collection_path(collection)
    assert_equal [ "Renamed Topic", position ], collection.reload.values_at(:name, :index_position)

    delete registration_collection_path(collection)
    assert_redirected_to collection_path(collection)
    assert_nil collection.reload.index_position
  end

  test "lifecycle and rename refusals return to the same live Collection unchanged" do
    duplicate = @user.collections.create!(name: "Duplicate Topic")
    empty = @user.collections.create!(name: "Refused Topic")
    original = empty.attributes

    patch collection_path(empty), params: { collection: { name: duplicate.name } }
    assert_response :unprocessable_entity
    assert_equal original, empty.reload.attributes
    assert_select ".form-errors"

    post register_collection_path(empty)
    assert_redirected_to collection_path(empty)
    assert_equal "That Collection can't do that.", flash[:alert]
    assert_equal original, empty.reload.attributes

    delete registration_collection_path(empty)
    assert_redirected_to collection_path(empty)
    assert_equal "That Collection can't do that.", flash[:alert]
    assert_equal original, empty.reload.attributes
  end

  test "guarded delete tombstones only a never-used Collection" do
    never_used = @user.collections.create!(name: "Disposable")
    original = never_used.attributes

    delete collection_path(never_used)

    assert_redirected_to journal_index_path
    assert_equal "Collection deleted.", flash[:notice]
    deleted = never_used.reload
    assert_not_nil deleted.deleted_at
    assert_equal original.except("deleted_at", "updated_at"),
      deleted.attributes.except("deleted_at", "updated_at")

    get collection_path(deleted)
    assert_response :not_found
    assert_select "h1", text: "Collection not found"
  end

  test "guarded delete refuses kept soft-deleted and mixed entry history without cascades" do
    collections = [
      create_filled_collection("Kept history"),
      create_filled_collection("Deleted history"),
      create_filled_collection("Mixed history")
    ]
    collections.second.entries.first.soft_delete!
    create_collection_entry(collections.third, text: "Deleted too").soft_delete!
    original_entries = collections.to_h { |collection| [ collection.id, collection.entries.map(&:attributes) ] }

    collections.each do |collection|
      delete collection_path(collection)
      assert_redirected_to collection_path(collection)
      assert_equal "That Collection can't do that.", flash[:alert]
      assert_nil collection.reload.deleted_at
      assert_equal original_entries.fetch(collection.id), collection.entries.map(&:attributes)
    end
  end

  test "every Collection id route renders the same 404 for malformed missing foreign and deleted ids" do
    foreign = users(:two).collections.create!(name: "Private foreign Topic")
    deleted = @user.collections.create!(name: "Private deleted Topic")
    deleted.soft_delete_if_unused!
    probe_ids = [ "not-a-uuid", "0198f3b9-0000-7000-8000-0000000000ff", foreign.id, deleted.id ]
    requesters = [
      ->(id) { get collection_path(id) },
      ->(id) { patch collection_path(id), params: { collection: { name: "Changed" } } },
      ->(id) { post register_collection_path(id) },
      ->(id) { delete registration_collection_path(id) },
      ->(id) { delete collection_path(id) }
    ]

    requesters.each do |requester|
      bodies = probe_ids.map do |id|
        snapshot = Collection.order(:id).pluck(:id, :name, :index_position, :deleted_at)
        requester.call(id)
        assert_response :not_found
        assert_equal snapshot, Collection.order(:id).pluck(:id, :name, :index_position, :deleted_at)
        assert_select "h1", text: "Collection not found"
        assert_select "a[href='#{journal_index_path}']", text: "Back to Index"
        assert_select ".tab-bar__item[aria-current='page']", text: "Index", count: 1
        assert_not_includes response.body, id
        assert_not_includes response.body, foreign.name
        assert_not_includes response.body, deleted.name
        response.body
      end
      assert_equal 1, bodies.uniq.size
    end
  end

  test "crafted Turbo Collection mutations render the themed HTML missing state" do
    post register_collection_path("missing", format: :turbo_stream)

    assert_response :not_found
    assert_select "h1", text: "Collection not found"
    assert_select ".tab-bar__item[aria-current='page']", text: "Index", count: 1
  end

  test "Collection capture accepts every root kind without a page date or implicit registration" do
    collection = @user.collections.create!(name: "Capture Topic")
    collection.update!(hlc: "dormant", server_seq: 17)

    travel_to Time.zone.local(2026, 8, 25, 12) do
      captures = [
        [ "task words", "task", nil ],
        [ "dinner tomorrow 6pm", "event", nil ],
        [ "remember this", "note", "not-a-date" ]
      ]
      captures.each do |line, kind, on|
        params = {
          line: line, default_kind: kind, placement: "collection", collection_id: collection.id
        }
        params[:on] = on if on
        post entries_path, params: params
        assert_redirected_to collection_path(collection)
        assert_nil collection.reload.index_position,
          "capture must not register the Collection as a side effect"
        assert_equal [ "dormant", 17 ], collection.values_at(:hlc, :server_seq)
      end
    end

    residents = @user.entries.collection_page(collection.id).where(text: [ "task words", "dinner", "remember this" ])
    assert_equal %w[task event note], residents.pluck(:kind)
    assert_equal [ "collection" ], residents.distinct.pluck(:page_kind)
    assert_equal [ nil ], residents.distinct.pluck(:page_on)
    assert_equal [ collection.id ], residents.distinct.pluck(:collection_id)
    event = residents.find_by!(kind: "event")
    assert_equal Date.new(2026, 8, 26), event.occurs_on
    assert_equal "18:00", event.time_of_day
    assert_equal [ nil, "dormant", 17 ], collection.reload.values_at(:index_position, :hlc, :server_seq)

    assert_no_difference -> { Entry.count } do
      post entries_path, params: {
        line: "   ", placement: "collection", collection_id: collection.id
      }
    end
    assert_redirected_to collection_path(collection)
  end

  test "Collection capture missing destinations share the uniform 404 and write nothing" do
    foreign = users(:two).collections.create!(name: "Foreign capture")
    deleted = @user.collections.create!(name: "Deleted capture")
    deleted.soft_delete_if_unused!
    ids = [ "not-a-uuid", "0198f3b9-0000-7000-8000-0000000000ee", foreign.id, deleted.id ]

    bodies = ids.map do |id|
      assert_no_difference -> { Entry.count } do
        post entries_path, params: {
          line: "must not leak", placement: "collection", collection_id: id
        }
      end
      assert_response :not_found
      assert_not_includes response.body, id
      assert_not_includes response.body, foreign.name
      response.body
    end
    assert_equal 1, bodies.uniq.size

    assert_no_difference -> { Entry.count } do
      post entries_path(format: :turbo_stream), params: {
        line: "turbo must not leak", placement: "collection", collection_id: "missing"
      }
    end
    assert_response :not_found
    assert_select "h1", text: "Collection not found"
  end

  test "page titles precede their context on every journal screen" do
    collection = @user.collections.create!(name: "Heading Topic")
    screens = {
      journal_index_path => "Index",
      collection_path(collection) => "Heading Topic",
      collection_path("missing") => "Collection not found",
      daily_log_path(date: Time.zone.today.iso8601) => "Daily Log",
      monthly_log_path => "Monthly Log",
      future_log_path => "Future Log"
    }

    screens.each do |path, title|
      get path
      document = Nokogiri::HTML(response.body)
      assert_equal title, document.at_css("main h1").text.strip
    end

    get daily_log_path(date: Time.zone.today.iso8601)
    assert_select ".daily-log__heading h1 + .daily-log__eyebrow"
    get journal_index_path
    assert_select ".collection-page__heading h1 + .collection-page__context"
    get collection_path(collection)
    assert_select ".collection-page__heading h1 + .collection-page__context"
  end

  private

  def create_filled_collection(name)
    collection = @user.collections.create!(name: name)
    create_collection_entry(collection)
    collection
  end

  def create_collection_entry(collection, text: "Collection entry", kind: "task", state: "open", **attributes)
    collection.entries.create!({
      user: collection.user,
      kind: kind,
      state: state,
      text: text,
      tags: [],
      page_kind: "collection",
      page_on: nil
    }.merge(attributes))
  end
end
