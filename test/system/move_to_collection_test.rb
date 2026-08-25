require "application_system_test_case"

# Exercises the exact-Topic Move to Collection gesture through its collapsed
# two-step strip and the server guard behind controls that are absent.
class MoveToCollectionTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
    @destination = @user.collections.create!(name: "Camping Plans")
  end

  test "1 a Daily note moves to one unindexed Collection root and stays on its source" do
    sign_in
    capture_note "call the ranger 5pm +camping"
    note = @user.entries.find_by!(text: "call the ranger")

    assert_collapsed_actions(note)
    reveal_actions(note)
    within entry_selector(note) do
      assert_button "Move to Collection…", exact: true
      assert_no_button "Complete"
      assert_no_button "Schedule…", exact: true
      click_button "Move to Collection…", exact: true
      assert_selector ".entry__toggle[aria-expanded='true']"
      assert_selector "[data-step='actions'][hidden]", visible: :all
      assert_selector ".entry__move-step:not([hidden])"
      assert_field "Exact Topic"
      assert_selector "input[name='topic'][autocomplete='off']"
      find("button[aria-label='Cancel moving to Collection']").click
      assert_no_field "Exact Topic"
      assert_button "Move to Collection…", exact: true

      click_button "Move to Collection…", exact: true
      fill_in "Exact Topic", with: "  CAMPING PLANS  "
      click_button "Move", exact: true
    end

    assert_current_path daily_log_path(date: Time.zone.today.iso8601)
    assert_selector "#{entry_selector(note)} .entry__glyph", text: ">"
    within(entry_selector(note)) { assert_text "→ Camping Plans" }
    successor = note.reload.successor
    assert_not_nil successor
    assert_nil successor.parent_id
    assert_equal [ "collection", @destination.id, nil, nil ],
      successor.values_at(:page_kind, :collection_id, :occurs_on, :time_of_day)
    assert_nil @destination.reload.index_position

    visit collection_path(@destination)
    assert_selector entry_selector(successor), text: "call the ranger", count: 1
    assert_no_selector entry_selector(note)
    assert_no_button "Remove from Index"
  end

  test "2 Calendar and Monthly Tasks residents move and return to their source views" do
    month = Time.zone.today.beginning_of_month
    calendar_task = create_task(
      "calendar move", page_kind: "monthly_calendar", page_on: month, occurs_on: Time.zone.today
    )
    monthly_task = create_task("tasks move", page_kind: "monthly_tasks", page_on: month)
    sign_in

    calendar_path = monthly_log_path(month: month.strftime("%Y-%m"))
    visit calendar_path
    move_visible_entry(calendar_task)
    assert_current_path calendar_path
    assert_selector "#{entry_selector(calendar_task)} .entry__glyph", text: ">"

    tasks_path = monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks")
    visit tasks_path
    move_visible_entry(monthly_task)
    assert_current_path tasks_path
    assert_selector "#{entry_selector(monthly_task)} .entry__glyph", text: ">"

    assert_equal [ calendar_task.id, monthly_task.id ].sort,
      @destination.entries.kept.pluck(:migrated_from_id).sort
    assert_nil @destination.reload.index_position
  end

  test "3 destination misses and ineligible residents refuse without changing rows" do
    deleted = @user.collections.create!(name: "Deleted Destination")
    deleted.soft_delete_if_unused!
    foreign = users(:two).collections.create!(name: "Foreign Destination")
    eligible = create_task("refused destination", page_kind: "daily", page_on: Time.zone.today)
    sign_in
    visit daily_log_path(date: Time.zone.today.iso8601)

    [ "Wrong Topic", deleted.name, foreign.name ].each do |topic|
      original_attributes = eligible.reload.attributes
      original_count = Entry.unscoped.count
      reveal_actions(eligible)
      within entry_selector(eligible) do
        click_button "Move to Collection…", exact: true
        fill_in "Exact Topic", with: topic
        click_button "Move", exact: true
      end
      assert_current_path daily_log_path(date: Time.zone.today.iso8601)
      assert_text "That entry can't do that."
      assert_equal original_attributes, eligible.reload.attributes
      assert_equal original_count, Entry.unscoped.count
      assert_nil eligible.successor
    end

    ineligible_residents.each do |entry, page_path, return_path|
      visit page_path
      within(entry_selector(entry)) { assert_no_button "Move to Collection…", exact: true }
      original_journal = journal_snapshot
      submit_crafted_move(entry)
      assert_current_path return_path
      assert_text "That entry can't do that."
      assert_equal original_journal, journal_snapshot
    end
  end

  test "4 exact-Topic move step stays accessible in both phone treatments" do
    note = create_note("phone move", page_kind: "daily", page_on: Time.zone.today)
    sign_in
    click_button "Theme: system", exact: true
    click_button "Hand: marker", exact: true
    assert_phone_move_step(note, width: 390, theme: "light", hand: "rock-salt")

    visit root_path
    click_button "Theme: light", exact: true
    click_button "Hand: rock salt", exact: true
    assert_phone_move_step(note, width: 320, theme: "dark", hand: "architects-daughter")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def capture_note(line)
    find("button[aria-label='Write on this page']").click
    find("button[aria-label='Note']").click
    fill_in "Rapid log…", with: line
    click_button "Log", exact: true
    assert_text line.split.first(3).join(" ")
  end

  def create_task(text, **placement)
    @user.entries.create!(
      kind: "task", state: "open", text: text, tags: [], **placement
    )
  end

  def create_note(text, **placement)
    @user.entries.create!(
      kind: "note", state: nil, text: text, tags: [], **placement
    )
  end

  def reveal_actions(entry)
    within(entry_selector(entry)) { find(".entry__toggle").click }
    within(entry_selector(entry)) { assert_selector ".entry__toggle[aria-expanded='true']" }
  end

  def assert_collapsed_actions(entry)
    within entry_selector(entry) do
      assert_selector ".entry__toggle[aria-expanded='false']"
      assert_selector ".entry__action-strip[hidden]", visible: :all
    end
  end

  def move_visible_entry(entry)
    reveal_actions(entry)
    within entry_selector(entry) do
      click_button "Move to Collection…", exact: true
      fill_in "Exact Topic", with: @destination.name
      click_button "Move", exact: true
    end
    assert_selector "#{entry_selector(entry)} .entry__glyph", text: ">"
  end

  def ineligible_residents
    done = create_task("done resident", page_kind: "daily", page_on: Time.zone.today)
    done.complete!
    moved_event = @user.entries.create!(
      kind: "event", state: nil, text: "moved event", tags: [],
      page_kind: "daily", page_on: Time.zone.today
    )
    moved_event.move_to!(
      page_kind: "future", page_on: nil,
      occurs_on: Time.zone.today.next_month.beginning_of_month,
      as_of: Time.zone.today
    )
    moved_note = create_note("moved note", page_kind: "daily", page_on: Time.zone.today)
    moved_note.move_to!(
      page_kind: "collection", page_on: nil, collection: @destination,
      as_of: Time.zone.today
    )
    collection_task = create_task(
      "collection resident", page_kind: "collection", page_on: nil, collection: @destination
    )
    future_task = create_task(
      "future resident", page_kind: "future", page_on: nil,
      occurs_on: Time.zone.today.next_month.beginning_of_month
    )
    daily_path = daily_log_path(date: Time.zone.today.iso8601)
    [
      [ done, daily_path, daily_path ],
      [ moved_event, daily_path, daily_path ],
      [ moved_note, daily_path, daily_path ],
      [ collection_task, collection_path(@destination), collection_path(@destination) ],
      [ future_task, future_log_path, daily_path ]
    ]
  end

  def submit_crafted_move(entry)
    page.execute_script(<<~JAVASCRIPT, move_to_collection_entry_path(entry), @destination.name)
      const form = document.createElement("form")
      form.method = "post"
      form.action = arguments[0]
      const fields = {
        topic: arguments[1],
        viewed_on: "#{Time.zone.today.iso8601}"
      }
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

  def assert_phone_move_step(entry, width:, theme:, hand:)
    page.current_window.resize_to(width, 844)
    visit daily_log_path(date: Time.zone.today.iso8601)
    assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
    reveal_actions(entry)
    within(entry_selector(entry)) { click_button "Move to Collection…", exact: true }
    within entry_selector(entry) do
      assert_selector ".entry__toggle[aria-expanded='true']"
      assert_field "Exact Topic"
      assert_button "Move", exact: true
      assert_selector "button[aria-label='Cancel moving to Collection']"
    end
    assert_no_horizontal_overflow
    assert_minimum_targets
    assert_no_tab_bar_collision
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

  def journal_snapshot
    @user.entries.order(:id).map(&:attributes)
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end
end
