require "test_helper"

# Pins the complete current-user Index and the remaining Collection commands.
class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "Index is authenticated and lists every kept current-user Topic in append order" do
    sign_out
    get journal_index_path
    assert_redirected_to new_session_path

    sign_in_as @user
    second = create_collection("Second")
    deleted = create_collection("Deleted")
    foreign = Collection.create_for(user: users(:two), topic: "Foreign")
    deleted.soft_delete_if_unused!

    get journal_index_path

    assert_response :success
    assert_select "h1:first-of-type", text: "Index"
    assert_select ".collection-page__heading h1 + .collection-page__context", text: "Your collections"
    document = Nokogiri::HTML(response.body)
    assert_equal [ collections(:camping).name, second.name ],
      document.css(".collection-index__topics a").map { |link| link.text.strip }
    assert_select "a", text: deleted.name, count: 0
    assert_select "a", text: foreign.name, count: 0
    assert_select "#locate_collection_toggle", count: 0
    assert_select "form[action='/collections/locate']", count: 0
    assert_select "button.collection-index__create-reveal[aria-controls='new_collection_panel']", count: 1
  end

  test "empty Index exposes both new Collection reveals and no hidden set" do
    collections(:camping).soft_delete_if_unused!

    get journal_index_path

    assert_response :success
    assert_select ".collection-index__empty", text: "Nothing indexed yet."
    assert_select "#new_collection_toggle"
    assert_select "#new_collection_panel[hidden]"
    assert_select "#index_create_reveal[aria-controls='new_collection_panel']"
    assert_select "input[name='collection[name]'][autocomplete='off']"
    assert_select "input[name='topic']", count: 0
  end

  test "create trims a Topic, ignores a crafted rank, and atomically opens its indexed page" do
    assert_difference -> { @user.collections.count }, 1 do
      post collections_path, params: {
        collection: { name: "  Camping   Notes  ", index_position: 99 }
      }
    end

    collection = @user.collections.find_by!(name: "Camping   Notes")
    assert_equal 2, collection.index_position
    assert_nil collection.hlc
    assert_nil collection.server_seq
    assert_redirected_to collection_path(collection)
    assert_equal "Collection created.", flash[:notice]
  end

  test "blank and duplicate create refusals keep input open without consuming a rank" do
    [ "   ", "camping trip" ].each do |topic|
      snapshot = @user.collections.order(:id).pluck(:id, :index_position)

      post collections_path, params: { collection: { name: topic, index_position: 80 } }

      assert_response :unprocessable_entity
      assert_equal snapshot, @user.collections.order(:id).pluck(:id, :index_position)
      assert_select "#new_collection_toggle[aria-expanded='true']"
      assert_select "#new_collection_panel:not([hidden])"
      assert_select "input[name='collection[name]'][value=?]", topic
      assert_select ".form-errors"
    end

    created = create_collection("After refusals")
    assert_equal 2, created.index_position
  end

  test "Collection page has corrected context and empty copy with no registration surface" do
    collection = create_collection("Rendered Topic")

    get collection_path(collection)

    assert_response :success
    assert_select "h1", text: collection.name
    assert_select ".collection-page__context", text: "Collection"
    assert_select "button[aria-label='Write on this page'] .entry-list__empty", text: "Nothing logged yet."
    assert_select "#manage_collection_toggle", text: "Manage"
    assert_select "input[name='collection[name]']"
    assert_select "input[name='line']"
    assert_select "button", text: "Add to Index", count: 0
    assert_select "button", text: "Remove from Index", count: 0
    assert_select ".collection-page__registration", count: 0
    assert_not_includes response.body, "not indexed"
    assert_not_includes response.body, "indexed"
  end

  test "rename preserves position and refusal restores the persisted Collection" do
    collection = create_collection("Rename me")
    duplicate = collections(:camping)
    position = collection.index_position

    patch collection_path(collection), params: { collection: { name: " Renamed Topic ", index_position: 1 } }
    assert_redirected_to collection_path(collection)
    assert_equal [ "Renamed Topic", position ], collection.reload.values_at(:name, :index_position)

    patch collection_path(collection), params: { collection: { name: duplicate.name } }
    assert_response :unprocessable_entity
    assert_equal [ "Renamed Topic", position ], collection.reload.values_at(:name, :index_position)
    assert_select "#manage_collection_toggle[aria-expanded='true']"
    assert_select ".form-errors"
  end

  test "guarded deletion retains its rank and a later creation appends after it" do
    collection = create_collection("Disposable")
    position = collection.index_position

    delete collection_path(collection)

    assert_redirected_to journal_index_path
    assert_equal "Collection deleted.", flash[:notice]
    assert_not_nil collection.reload.deleted_at
    assert_equal position, collection.index_position
    assert_response :redirect

    later = create_collection("Later")
    assert_equal position + 1, later.index_position

    get collection_path(collection)
    assert_response :not_found
    assert_select "h1", text: "Collection not found"
  end

  test "used Collection deletion refuses without changing the page or entries" do
    collection = create_collection("Used")
    entry = create_collection_entry(collection)
    snapshot = collection.attributes

    delete collection_path(collection)

    assert_redirected_to collection_path(collection)
    assert_equal "That Collection can't do that.", flash[:alert]
    assert_equal snapshot, collection.reload.attributes
    assert_predicate entry.reload, :persisted?
  end

  test "remaining member routes give one nondisclosing 404 and write nothing" do
    foreign = Collection.create_for(user: users(:two), topic: "Private foreign Topic")
    deleted = create_collection("Private deleted Topic")
    deleted.soft_delete_if_unused!
    ids = [ "not-a-uuid", "0198f3b9-0000-7000-8000-0000000000ff", foreign.id, deleted.id ]
    requesters = [
      ->(id) { get collection_path(id) },
      ->(id) { patch collection_path(id), params: { collection: { name: "Changed" } } },
      ->(id) { delete collection_path(id) }
    ]

    requesters.each do |requester|
      bodies = ids.map do |id|
        snapshot = Collection.order(:id).pluck(:id, :name, :index_position, :deleted_at)
        requester.call(id)
        assert_response :not_found
        assert_equal snapshot, Collection.order(:id).pluck(:id, :name, :index_position, :deleted_at)
        assert_select "h1", text: "Collection not found"
        assert_not_includes response.body, foreign.name
        response.body
      end
      assert_equal 1, bodies.uniq.size
    end
  end

  test "removed locate register and registration routes return route 404 and write nothing" do
    collection = create_collection("Stable")
    requests = [
      -> { post "/collections/locate", params: { topic: collection.name } },
      -> { post "/collections/#{collection.id}/register" },
      -> { delete "/collections/#{collection.id}/registration" }
    ]

    requests.each do |request|
      snapshot = Collection.order(:id).map(&:attributes)
      request.call
      assert_response :not_found
      assert_equal snapshot, Collection.order(:id).map(&:attributes)
    end
  end

  test "Collection capture accepts every root kind without changing position or dormant sync fields" do
    collection = create_collection("Capture Topic")
    collection.update!(hlc: "dormant", server_seq: 17)
    snapshot = collection.reload.values_at(:index_position, :hlc, :server_seq)

    travel_to Time.zone.local(2026, 8, 25, 12) do
      [ [ "task words", "task" ], [ "dinner tomorrow 6pm", "event" ], [ "remember this", "note" ] ].each do |line, kind|
        post entries_path, params: {
          line: line, default_kind: kind, placement: "collection", collection_id: collection.id
        }
        assert_redirected_to collection_path(collection)
        assert_equal snapshot, collection.reload.values_at(:index_position, :hlc, :server_seq)
      end
    end

    residents = @user.entries.collection_page(collection.id)
      .where(text: [ "task words", "dinner", "remember this" ])
    assert_equal %w[task event note], residents.pluck(:kind)
    assert_equal [ "collection" ], residents.distinct.pluck(:page_kind)
    assert_equal [ collection.id ], residents.distinct.pluck(:collection_id)
  end

  test "Collection capture missing destinations share the uniform 404 and write nothing" do
    foreign = Collection.create_for(user: users(:two), topic: "Foreign capture")
    deleted = create_collection("Deleted capture")
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
  end

  private

  def create_collection(topic)
    Collection.create_for(user: @user, topic: topic)
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
