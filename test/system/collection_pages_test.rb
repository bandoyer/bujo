require "application_system_test_case"

# Exercises the deliberate Index and writable Collection page through their
# real phone-sized gestures.
class CollectionPagesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "1 create an empty Collection then capture all three root kinds" do
    sign_in
    click_link "Index", exact: true
    assert_current_path journal_index_path
    assert_text "Nothing indexed yet."
    assert_no_text collections(:camping).name

    reveal "new_collection_toggle", "new_collection_panel"
    fill_in "Topic", with: "Camping Notes"
    click_button "Create", exact: true
    assert_text "Collection · not indexed"
    collection = Collection.find(page.current_path.split("/").last)
    assert_equal [ @user, "Camping Notes" ], [ collection.user, collection.name ]
    assert_current_path collection_path(collection)
    assert_text "Add a first entry before indexing."
    assert_no_button "Add to Index"

    capture "reserve campsite", kind: "Task", expected_text: "reserve campsite"
    capture "campfire tomorrow 6pm", kind: "Event", expected_text: "campfire"
    capture "call after five", kind: "Note", expected_text: "call after five"

    assert_equal %w[task event note], @user.entries.collection_page(collection.id).pluck(:kind)
    assert_text "reserve campsite"
    assert_text "campfire"
    assert_text "call after five"
    assert_button "Add to Index"
    assert_no_selector ".entry__toggle"
    assert_no_selector ".entry__action-strip"
  end

  test "2 register rename unindex and re-register in deliberate order" do
    first = create_filled_collection("Trail Plans")
    second = create_filled_collection("Reading List")
    sign_in
    visit collection_path(first)
    click_button "Add to Index"
    visit collection_path(second)
    click_button "Add to Index"
    assert_text "Collection · indexed"

    click_link "Index", exact: true
    assert_equal [ "Trail Plans", "Reading List" ], all(".collection-index__topic-link").map(&:text)

    click_link "Trail Plans", exact: true
    reveal "manage_collection_toggle", "manage_collection_panel"
    fill_in "Rename Topic", with: "Camp Plan"
    click_button "Rename", exact: true
    assert_selector "h1", text: "Camp Plan"
    click_button "Remove from Index"
    assert_text "Collection · not indexed"
    click_link "Index", exact: true
    assert_no_link "Camp Plan"
    assert_link "Reading List"

    visit collection_path(first)
    click_button "Add to Index"
    assert_text "Collection · indexed"
    click_link "Index", exact: true
    assert_equal [ "Reading List", "Camp Plan" ], all(".collection-index__topic-link").map(&:text)
  end

  test "3 Open by Topic reaches only an exact known unindexed Topic" do
    collection = @user.collections.create!(name: "Garden Plans")
    sign_in
    click_link "Index", exact: true
    reveal "locate_collection_toggle", "locate_collection_panel"
    fill_in "Exact Topic", with: "garden"
    click_button "Open", exact: true
    assert_current_path journal_index_path
    assert_text "No Collection with that exact Topic."
    assert_no_text collection.name

    fill_in "Exact Topic", with: "  GARDEN PLANS  "
    click_button "Open", exact: true
    assert_current_path collection_path(collection)
  end

  test "4 guarded delete returns to Index and old or foreign paths share missing chrome" do
    disposable = @user.collections.create!(name: "Disposable Topic")
    foreign = users(:two).collections.create!(name: "Private Topic")
    sign_in
    visit collection_path(disposable)
    reveal "manage_collection_toggle", "manage_collection_panel"
    accept_confirm { click_button "Delete Collection" }
    assert_current_path journal_index_path
    assert_text "Collection deleted."

    [ collection_path(disposable), collection_path(foreign), collection_path("not-a-uuid") ].each do |path|
      visit path
      assert_text "Collection not found"
      assert_no_text disposable.name
      assert_no_text foreign.name
      assert_active_tab "Index"
      click_link "Back to Index"
      assert_current_path journal_index_path
    end
  end

  test "5 new screens honor both themes hands narrow layout and 44 pixel controls" do
    collection = create_filled_collection("A Topic Long Enough To Exercise Narrow Phone Wrapping")
    collection.register!
    sign_in
    click_button "Theme: system", exact: true
    click_button "Hand: marker", exact: true

    [ 390, 320 ].each do |width|
      page.current_window.resize_to(width, 844)
      [ journal_index_path, collection_path(collection) ].each do |path|
        visit path
        assert_selector "html[data-theme='light'][data-hand='rock-salt']", visible: :all
        assert_no_horizontal_overflow
        assert_minimum_targets
        assert_active_tab "Index"
      end
    end

    visit root_path
    click_button "Theme: light", exact: true
    click_button "Hand: rock salt", exact: true
    [ journal_index_path, collection_path(collection) ].each do |path|
      visit path
      assert_selector "html[data-theme='dark'][data-hand='architects-daughter']", visible: :all
      assert_no_horizontal_overflow
      assert_minimum_targets
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def reveal(toggle_id, panel_id)
    find("##{toggle_id}").click
    assert_selector "##{toggle_id}[aria-expanded='true']"
    assert_selector "##{panel_id}:not([hidden])"
  end

  def capture(line, kind:, expected_text:)
    find("button[aria-label='Write on this page']").click
    find("button[aria-label='#{kind}']").click unless kind == "Task"
    fill_in "Rapid log…", with: line
    click_button "Log", exact: true
    assert_text expected_text
    assert_current_path %r{/collections/}
  end

  def create_filled_collection(name)
    collection = @user.collections.create!(name: name)
    collection.entries.create!(
      user: @user, kind: "task", state: "open", text: "Resident", tags: [],
      page_kind: "collection", page_on: nil
    )
    collection
  end

  def assert_active_tab(label)
    assert_selector ".tab-bar__item[aria-current='page']", text: label, count: 1
  end

  def assert_no_horizontal_overflow
    overflow = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
    assert_not overflow, "page must not scroll horizontally at phone width"
  end

  def assert_minimum_targets
    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("button, a, input:not([type='hidden'])"))
        .filter((element) => {
          const rect = element.getBoundingClientRect()
          return rect.width > 0 && rect.height > 0 && (rect.width < 44 || rect.height < 44)
        })
        .map((element) => element.textContent.trim() || element.getAttribute("aria-label"))
    JAVASCRIPT
    assert_empty undersized, "interactive targets below 44px: #{undersized.inspect}"
  end
end
