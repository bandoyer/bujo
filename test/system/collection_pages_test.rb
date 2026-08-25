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
    assert_selector ".entry__toggle", count: 1
    assert_selector ".entry__action-strip", count: 1, visible: :all
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

  test "6 empty and refused reader states stay useful and safe at phone widths" do
    empty = @user.collections.create!(name: "Hidden Empty Topic")
    sign_in
    click_button "Theme: system", exact: true

    { "light" => "Theme: light", "dark" => nil }.each do |theme, next_theme_button|
      [ 390, 320 ].each do |width|
        page.current_window.resize_to(width, 844)
        assert_empty_reader_states(empty, theme)
      end

      next unless next_theme_button

      visit root_path
      click_button next_theme_button, exact: true
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "7 deletion is offered only before a Collection has any entry history" do
    never_used = @user.collections.create!(name: "Never Used")
    kept_history = create_filled_collection("Kept History")
    deleted_history = create_filled_collection("Deleted History")
    deleted_entry = deleted_history.entries.first
    deleted_entry.soft_delete!(at: Time.zone.parse("2026-08-25 12:30:00"))
    sign_in

    visit collection_path(never_used)
    reveal "manage_collection_toggle", "manage_collection_panel"
    assert_button "Delete Collection"
    accept_confirm { click_button "Delete Collection" }
    assert_current_path journal_index_path
    assert_text "Collection deleted."
    visit collection_path(never_used)
    assert_selector "h1:first-of-type", text: "Collection not found"

    visit collection_path(kept_history)
    reveal "manage_collection_toggle", "manage_collection_panel"
    assert_no_button "Delete Collection"
    assert_equal 1, kept_history.entries.count

    visit collection_path(deleted_history)
    reveal "manage_collection_toggle", "manage_collection_panel"
    assert_no_button "Delete Collection"
    assert_equal 1, Entry.unscoped.where(collection_id: deleted_history.id).count
    assert_not_nil deleted_entry.reload.deleted_at
  end

  test "8 Collection reads and exact Topic lookup stay within the signed in user" do
    first_user_collection = create_filled_collection("First User Secret Topic")
    first_user_collection.register!
    first_user_entry_text = first_user_collection.entries.first.text

    @user = users(:two)
    second_user_collection = create_filled_collection("Second User Topic")
    second_user_collection.register!
    sign_in

    visit journal_index_path
    assert_equal [ second_user_collection.name ], all(".collection-index__topic-link").map(&:text)
    assert_no_text first_user_collection.name

    visit collection_path(first_user_collection)
    assert_selector "h1:first-of-type", text: "Collection not found"
    assert_no_text first_user_collection.name
    assert_no_text first_user_entry_text

    visit journal_index_path
    reveal "locate_collection_toggle", "locate_collection_panel"
    fill_in "Exact Topic", with: first_user_collection.name
    click_button "Open", exact: true
    assert_current_path journal_index_path
    assert_text "No Collection with that exact Topic."
    assert_selector "#locate_collection_toggle[aria-expanded='true']"
    assert_no_text first_user_collection.name
  end

  test "9 crafted Collection gestures are refused without changing rows" do
    empty = @user.collections.create!(name: "Crafted Empty")
    used = create_filled_collection("Crafted History")
    duplicate = @user.collections.create!(name: "Duplicate Topic")
    foreign = users(:two).collections.create!(name: "Foreign Capture Topic")
    sign_in

    visit collection_path(empty)
    empty_attributes = empty.attributes
    submit_crafted_request(register_collection_path(empty), method: :post)
    assert_current_path collection_path(empty)
    assert_text "That Collection can't do that."
    assert_equal empty_attributes, empty.reload.attributes

    visit collection_path(used)
    used_attributes = used.attributes
    entry_attributes = used.entries.first.attributes
    submit_crafted_request(collection_path(used), method: :delete)
    assert_current_path collection_path(used)
    assert_text "That Collection can't do that."
    assert_equal used_attributes, used.reload.attributes
    assert_equal entry_attributes, used.entries.first.reload.attributes

    visit collection_path(used)
    submit_crafted_request(
      collection_path(used),
      method: :patch,
      params: { "collection[name]" => duplicate.name }
    )
    assert_current_path collection_path(used)
    assert_selector ".form-errors"
    assert_selector "h1", text: used.name
    assert_equal used_attributes, used.reload.attributes
    assert_equal duplicate.name, duplicate.reload.name

    visit collection_path(used)
    entry_count = Entry.count
    foreign_attributes = foreign.attributes
    submit_crafted_request(
      entries_path,
      method: :post,
      params: {
        "line" => "foreign collection injection",
        "placement" => "collection",
        "collection_id" => foreign.id,
        "default_kind" => "task"
      }
    )
    assert_selector "h1:first-of-type", text: "Collection not found"
    assert_no_text foreign.name
    assert_equal entry_count, Entry.count
    assert_equal foreign_attributes, foreign.reload.attributes
    assert_equal used_attributes, used.reload.attributes
    assert_equal entry_attributes, used.entries.first.reload.attributes
  end

  test "sans hand uses Public Sans for new and existing screen metadata" do
    collection = create_filled_collection("Sans Metadata")
    sign_in
    [ "marker", "rock salt", "architects", "patrick", "gochi" ].each do |hand|
      click_button "Hand: #{hand}", exact: true
    end
    assert_selector "html[data-hand='sans']", visible: :all

    visit collection_path(collection)
    assert_public_sans ".collection-page__context"

    visit root_path
    assert_public_sans ".day-navigation"
  end

  test "10 Collection task lifecycle stays on its page and refuses outbound commands" do
    collection = @user.collections.create!(name: "Lifecycle Commands")
    task = create_collection_task(collection, "Command resident")
    sign_in
    visit collection_path(collection)

    assert_collapsed_collection_actions(task)
    reveal_entry_actions(task)
    within entry_selector(task) do
      assert_button "Complete"
      assert_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
      click_button "Complete"
    end
    assert_current_path collection_path(collection)
    assert_selector "#{entry_selector(task)} form[action='#{reopen_entry_path(task)}']", visible: :all
    assert_equal "done", task.reload.state

    refused_attributes = task.attributes
    submit_crafted_request(complete_entry_path(task), method: :post)
    assert_current_path collection_path(collection)
    assert_text "That entry can't do that."
    assert_equal refused_attributes, task.reload.attributes

    reveal_entry_actions(task)
    within(entry_selector(task)) { click_button "Reopen" }
    assert_current_path collection_path(collection)
    assert_selector "#{entry_selector(task)} form[action='#{complete_entry_path(task)}']", visible: :all
    assert_equal "open", task.reload.state

    reveal_entry_actions(task)
    within(entry_selector(task)) { click_button "Strike" }
    assert_current_path collection_path(collection)
    assert_selector "#{entry_selector(task)} form[action='#{reopen_entry_path(task)}']", visible: :all
    assert_equal "struck", task.reload.state

    reveal_entry_actions(task)
    within(entry_selector(task)) { click_button "Reopen" }
    assert_current_path collection_path(collection)
    assert_selector "#{entry_selector(task)} form[action='#{complete_entry_path(task)}']", visible: :all
    assert_equal "open", task.reload.state

    [
      [ migrate_entry_path(task), {} ],
      [ schedule_entry_path(task), { "date" => Time.zone.today.next_month.beginning_of_month.iso8601 } ]
    ].each do |path, params|
      original_attributes = task.attributes
      submit_crafted_request(path, method: :post, params: params)
      assert_current_path collection_path(collection)
      assert_text "That entry can't do that."
      assert_equal original_attributes, task.reload.attributes
      assert_nil task.successor
    end
  end

  test "11 open Collection actions fit both themed phone treatments" do
    collection = @user.collections.create!(name: "Phone Command Layout")
    task = create_collection_task(collection, "A command row long enough to wrap on a narrow phone")
    sign_in
    click_button "Theme: system", exact: true
    click_button "Hand: marker", exact: true

    assert_collection_action_layout(collection, task, width: 390, theme: "light", hand: "rock-salt")

    visit root_path
    click_button "Theme: light", exact: true
    click_button "Hand: rock salt", exact: true
    assert_collection_action_layout(collection, task, width: 320, theme: "dark", hand: "architects-daughter")
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

  def create_collection_task(collection, text)
    collection.entries.create!(
      user: @user, kind: "task", state: "open", text: text, tags: [],
      page_kind: "collection", page_on: nil
    )
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end

  def assert_collapsed_collection_actions(entry)
    within entry_selector(entry) do
      assert_selector ".entry__toggle[aria-expanded='false']"
      assert_selector ".entry__action-strip[hidden]", visible: :all
    end
  end

  def reveal_entry_actions(entry)
    within(entry_selector(entry)) { find(".entry__toggle").click }
    within entry_selector(entry) do
      assert_selector ".entry__toggle[aria-expanded='true']"
      assert_selector ".entry__action-strip:not([hidden])"
    end
  end

  def assert_collection_action_layout(collection, task, width:, theme:, hand:)
    page.current_window.resize_to(width, 844)
    visit collection_path(collection)
    assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
    reveal_entry_actions(task)
    within entry_selector(task) do
      assert_button "Complete"
      assert_button "Strike"
      assert_no_button "Migrate"
      assert_no_button "Schedule…", exact: true
    end
    assert_reader_layout_safe
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

  def assert_empty_reader_states(collection, theme)
    visit journal_index_path
    assert_selector "html[data-theme='#{theme}']", visible: :all
    assert_text "Nothing indexed yet."
    assert_button "New Collection"
    assert_no_text collection.name
    assert_reader_layout_safe

    visit collection_path(collection)
    assert_selector "html[data-theme='#{theme}']", visible: :all
    assert_text "Nothing logged yet."
    assert_text "Add a first entry before indexing."
    assert_no_button "Add to Index"
    assert_target_size "button[aria-label='Write on this page']"
    assert_reader_layout_safe

    visit journal_index_path
    reveal "locate_collection_toggle", "locate_collection_panel"
    fill_in "Exact Topic", with: "Hidden Empty"
    click_button "Open", exact: true
    assert_text "No Collection with that exact Topic."
    assert_selector "#locate_collection_toggle[aria-expanded='true']"
    assert_selector "#locate_collection_panel:not([hidden])"
    assert_no_selector ".collection-index__topics"
    assert_no_text collection.name
    assert_reader_layout_safe

    visit collection_path("missing-collection")
    assert_equal "Collection not found", all("h1").first.text
    assert_active_tab "Index"
    assert_target_size ".collection-page__back"
    assert_reader_layout_safe
  end

  def assert_reader_layout_safe
    assert_no_horizontal_overflow
    assert_minimum_targets
    assert_no_tab_bar_collision
  end

  def assert_no_tab_bar_collision
    collisions = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const tab = document.querySelector(".tab-bar").getBoundingClientRect()
        return Array.from(document.querySelectorAll("main button, main a, main input:not([type='hidden'])"))
          .filter((element) => !element.closest(".tab-bar"))
          .filter((element) => {
            const rect = element.getBoundingClientRect()
            return rect.width > 0 && rect.height > 0 && rect.bottom > tab.top && rect.top < tab.bottom
          })
          .map((element) => element.textContent.trim() || element.getAttribute("aria-label"))
      })()
    JAVASCRIPT
    assert_empty collisions, "fixed tab bar covers interactive content: #{collisions.inspect}"
  end

  def assert_target_size(selector)
    dimensions = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
        return [rect.width, rect.height]
      })()
    JAVASCRIPT
    assert_operator dimensions.first, :>=, 44
    assert_operator dimensions.last, :>=, 44
  end

  def submit_crafted_request(path, method:, params: {})
    page.execute_script(<<~JAVASCRIPT, path, method.to_s, params.to_json)
      const form = document.createElement("form")
      form.method = "post"
      form.action = arguments[0]
      const requestMethod = arguments[1]
      const fields = JSON.parse(arguments[2])
      if (requestMethod !== "post") fields._method = requestMethod
      const csrfToken = document.querySelector("meta[name='csrf-token']")
      if (csrfToken) fields.authenticity_token = csrfToken.content
      Object.entries(fields).forEach(([name, value]) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = name
        input.value = value
        form.appendChild(input)
      })
      document.body.appendChild(form)
      form.submit()
    JAVASCRIPT
  end

  def assert_public_sans(selector)
    font_family = page.evaluate_script(
      "getComputedStyle(document.querySelector(#{selector.to_json})).fontFamily"
    )
    assert_match(/\A\"?Public Sans/, font_family)
  end
end
