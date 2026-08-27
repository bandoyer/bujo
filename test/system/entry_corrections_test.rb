require "application_system_test_case"

# Exercises the phone correction gestures through the real Stimulus and Rails
# boundaries, including native date input and stable row geometry.
class EntryCorrectionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "empty Daily copy is the writing surface and reveal does not write" do
    sign_in
    original_count = @user.entries.count

    assert_selector "button[aria-label='Write on this page'] #empty_daily_log",
      text: "Nothing logged yet."
    find("#empty_daily_log").click

    assert_field "Rapid log…", focused: true
    assert_equal original_count, @user.entries.count
  end

  test "Edit preserves settled state supports standalone kind correction and does not shift columns" do
    day = Time.zone.today
    done = create_entry(
      state: "done", text: "old settled words", priority: true, tags: %w[old],
      occurs_on: day, time_of_day: "08:05"
    )
    standalone = create_entry(text: "wrong bullet")
    sign_in

    original_geometry = row_geometry(done)
    reveal_actions(done)
    within entry_selector(done) do
      click_button "Edit", exact: true
      assert_field "Edit entry", with: "* old settled words +old #{day.iso8601} 08:05"
      assert_selector "button[aria-label='Task'][aria-pressed='true']"
      assert_no_selector "button[aria-label='Event']"
      assert_equal original_geometry, row_geometry(done)
      fill_in "Edit entry", with: "* corrected settled +kept #{day.iso8601} 09:10"
      click_button "Save", exact: true
    end
    assert_current_path daily_log_path(date: day.iso8601)
    assert_equal [ "done", "corrected settled", true, %w[kept], "09:10" ],
      done.reload.values_at(:state, :text, :priority, :tags, :time_of_day)
    assert_equal original_geometry, row_geometry(done)

    reveal_actions(standalone)
    within entry_selector(standalone) do
      click_button "Edit", exact: true
      find("button[aria-label='Note']").click
      fill_in "Edit entry", with: "corrected note"
      click_button "Save", exact: true
    end
    assert_selector "#{entry_selector(standalone)} .entry__text", text: "corrected note"
    assert_equal [ "note", nil, "corrected note" ],
      standalone.reload.values_at(:kind, :state, :text)
  end

  test "Edit Cancel restores row focus without writing" do
    entry = create_entry(text: "cancel words")
    original = entry.attributes
    sign_in
    reveal_actions(entry)

    within entry_selector(entry) do
      click_button "Edit", exact: true
      fill_in "Edit entry", with: "discard this"
      click_button "Cancel", exact: true
      assert_button "Edit", exact: true
    end

    assert_equal original, entry.reload.attributes
    assert_equal "entry_#{entry.id}_actions",
      page.evaluate_script("document.activeElement.getAttribute('aria-controls')")
  end

  test "existing Event and Note edits preserve identity placement and exact NULL state" do
    day = Time.zone.today
    event = create_entry(
      kind: "event", state: nil, text: "old event", occurs_on: day,
      time_of_day: "08:05", tags: %w[old]
    )
    note = create_entry(kind: "note", state: nil, text: "old note", tags: %w[old])
    event_structure = structural_attributes(event)
    note_structure = structural_attributes(note)
    sign_in

    reveal_actions(event)
    within entry_selector(event) do
      click_button "Edit", exact: true
      assert_selector "button[aria-label='Event'][aria-pressed='true']"
      fill_in "Edit entry", with: "changed event +camp #{day.next_day.iso8601} 14:30"
      click_button "Save", exact: true
    end
    assert_current_path daily_log_path(date: day.iso8601)
    assert_equal [ "event", nil, "changed event", %w[camp], day.next_day, "14:30" ],
      event.reload.values_at(:kind, :state, :text, :tags, :occurs_on, :time_of_day)
    assert_equal event_structure, structural_attributes(event)

    reveal_actions(note)
    within entry_selector(note) do
      click_button "Edit", exact: true
      assert_selector "button[aria-label='Note'][aria-pressed='true']"
      fill_in "Edit entry", with: "changed note +camp"
      click_button "Save", exact: true
    end
    assert_selector "#{entry_selector(note)} .entry__text", text: "changed note"
    assert_equal [ "note", nil, "changed note", %w[camp] ],
      note.reload.values_at(:kind, :state, :text, :tags)
    assert_equal note_structure, structural_attributes(note)
  end

  test "moved live end edits words with one inherited kind and no new successor" do
    day = Time.zone.today
    predecessor = create_entry(text: "movement source")
    live_end = predecessor.move_to!(
      page_kind: "monthly_tasks", page_on: day.next_month.beginning_of_month, as_of: day
    )
    original_count = @user.entries.count
    sign_in
    visit monthly_log_path(month: day.next_month.strftime("%Y-%m"), view: "tasks")

    reveal_actions(live_end)
    within entry_selector(live_end) do
      click_button "Edit", exact: true
      assert_selector ".rapid-log__kind", count: 1
      assert_selector "button[aria-label='Task'][aria-pressed='true']"
      assert_no_selector "button[aria-label='Event'], button[aria-label='Note']"
      fill_in "Edit entry", with: "changed live words +kept"
      click_button "Save", exact: true
    end

    assert_current_path monthly_log_path(month: day.next_month.strftime("%Y-%m"), view: "tasks")
    assert_selector "#{entry_selector(live_end)} .entry__text", text: "changed live words"
    assert_equal original_count, @user.entries.count
    assert_equal predecessor, live_end.reload.predecessor
    assert_nil live_end.successor
    assert_equal [ "task", "open", "changed live words", %w[kept] ],
      live_end.values_at(:kind, :state, :text, :tags)
  end

  test "wrapped row keeps glyph text and metadata origins through selection and Edit" do
    entry = create_entry(
      text: "ThisUnbrokenCorrectionNameMustWrapWithoutMovingTheJournalColumnsAcrossInteractiveStates",
      tags: %w[long-metadata]
    )
    sign_in
    page.current_window.resize_to(320, 844)

    at_rest = row_geometry(entry)
    reveal_actions(entry)
    selected = row_geometry(entry)
    within(entry_selector(entry)) { click_button "Edit", exact: true }
    edit_open = row_geometry(entry)

    assert_equal at_rest, selected
    assert_equal at_rest, edit_open
    assert_no_horizontal_overflow
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "Future Note child edits in place with Note truthfully selected" do
    occurs_on = Time.zone.today.next_month.beginning_of_month + 3.days
    root = create_entry(page_kind: "future", page_on: nil, occurs_on: occurs_on)
    child = create_entry(
      kind: "note", state: nil, text: "old child words", tags: %w[old],
      page_kind: "future", page_on: nil, occurs_on: nil, parent: root
    )
    structure = structural_attributes(child)
    sign_in
    visit future_log_path

    reveal_actions(child)
    within entry_selector(child) do
      click_button "Edit", exact: true
      assert_selector "button[aria-label='Task'][aria-pressed='false']"
      assert_selector "button[aria-label='Event'][aria-pressed='false']"
      assert_selector "button[aria-label='Note'][aria-pressed='true']"
      assert_selector "input[name='default_kind'][value='note']", visible: :hidden
      fill_in "Edit entry", with: "new child words +camp"
      click_button "Save", exact: true
    end

    assert_current_path future_log_path
    assert_selector "#{entry_selector(child)} .entry__text", text: "new child words"
    assert_equal [ "note", nil, "new child words", %w[camp], nil, nil ],
      child.reload.values_at(:kind, :state, :text, :tags, :occurs_on, :time_of_day)
    assert_equal structure, structural_attributes(child)
    assert_nil child.successor
  end

  test "refused Edit stays title-first open truthful focused and contained at both phone treatments" do
    cases = [
      [ 390, "light", "rock-salt", create_entry(text: "daily unchanged"),
        daily_log_path(date: Time.zone.today.iso8601), "Task" ],
      begin
        occurs_on = Time.zone.today.next_month.beginning_of_month + 4.days
        root = create_entry(page_kind: "future", page_on: nil, occurs_on: occurs_on)
        child = create_entry(
          kind: "note", state: nil, text: "future unchanged",
          page_kind: "future", page_on: nil, occurs_on: nil, parent: root
        )
        [ 320, "dark", "architects-daughter", child, future_log_path, "Note" ]
      end
    ]
    sign_in

    cases.each do |width, theme, hand, entry, path, selected_kind|
      page.current_window.resize_to(width, 844)
      visit daily_log_path(date: Time.zone.today.iso8601)
      set_preferences(theme:, hand:)
      visit path
      original = entry.reload.attributes
      reveal_actions(entry)
      within entry_selector(entry) do
        click_button "Edit", exact: true
        field = find_field("Edit entry")
        field.fill_in(with: "")
        page.execute_script("arguments[0].removeAttribute('required')", field)
        click_button "Save", exact: true
      end

      assert_current_path path
      assert_selector "[role='alert']", text: "That entry can't do that."
      assert_title_before_alert
      within entry_selector(entry) do
        assert_field "Edit entry", with: "", focused: true
        assert_selector "button[aria-label='#{selected_kind}'][aria-pressed='true']"
      end
      assert_equal original, entry.reload.attributes
      assert_no_horizontal_overflow
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "native Schedule routes the last later current-month day to Calendar" do
    event = create_entry(kind: "event", state: nil, text: "same month event", time_of_day: "14:00")
    scheduled_on = Time.zone.today.end_of_month
    sign_in
    reveal_actions(event)

    within entry_selector(event) do
      click_button "Schedule…", exact: true
      assert_field "Schedule for"
      field = find_field("Schedule for")
      page.execute_script(<<~JAVASCRIPT, field, scheduled_on.iso8601)
        arguments[0].value = arguments[1]
        arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
        arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
      JAVASCRIPT
      assert_operator field.rect.height, :>=, 44
      click_button "Schedule", exact: true
    end

    assert_current_path daily_log_path(date: Time.zone.today.iso8601)
    successor = event.reload.successor
    assert_equal [ "monthly_calendar", Time.zone.today.beginning_of_month, scheduled_on ],
      successor.values_at(:page_kind, :page_on, :occurs_on)
    assert_selector "#{entry_selector(event)} .entry__glyph", text: ">"
  end

  test "native Schedule is full width above its actions and routes both destinations on phones" do
    same_month = create_entry(kind: "event", state: nil, text: "same month", time_of_day: "14:00")
    later_month = create_entry(text: "later month")
    cases = [
      [ 390, "light", "rock-salt", same_month, Time.zone.today.end_of_month, "monthly_calendar" ],
      [ 320, "dark", "architects-daughter", later_month,
        Time.zone.today.next_month.beginning_of_month, "future" ]
    ]
    sign_in

    cases.each do |width, theme, hand, entry, scheduled_on, destination|
      page.current_window.resize_to(width, 844)
      visit daily_log_path(date: Time.zone.today.iso8601)
      set_preferences(theme:, hand:)
      visit daily_log_path(date: Time.zone.today.iso8601)
      original_origins = row_geometry(entry)
      reveal_actions(entry)
      within entry_selector(entry) do
        click_button "Schedule…", exact: true
        field = find_field("Schedule for")
        set_native_date(field, scheduled_on)
        assert_field "Schedule for", with: scheduled_on.iso8601
        assert_schedule_geometry
        assert_equal original_origins, row_geometry(entry)
        click_button "Schedule", exact: true
      end

      assert_current_path daily_log_path(date: Time.zone.today.iso8601)
      expected_glyph = destination == "future" ? "<" : ">"
      assert_selector "#{entry_selector(entry)} .entry__glyph", text: expected_glyph
      successor = entry.reload.successor
      assert_equal [ destination, scheduled_on ], successor.values_at(:page_kind, :occurs_on)
      assert_nil successor.page_on if destination == "future"
      assert_equal Time.zone.today.beginning_of_month, successor.page_on if destination == "monthly_calendar"
      assert_no_horizontal_overflow
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "ordinary Calendar and Monthly Tasks capture all three kinds" do
    sign_in
    month = Time.zone.today.beginning_of_month
    day = Time.zone.today.beginning_of_month

    visit monthly_log_path(month: month.strftime("%Y-%m"))
    %w[Task Event Note].each_with_index do |kind, offset|
      capture_day = day + offset.days
      within ".monthly-calendar__day[data-date='#{capture_day.iso8601}']" do
        find(".monthly-calendar__capture-reveal").click
      end
      panel = ".monthly-calendar__day[data-date='#{capture_day.iso8601}'] .monthly-calendar__capture-panel:not([hidden])"
      assert_selector "#{panel} input[placeholder='Rapid log…']"
      find("#{panel} button[aria-label='#{kind}']").click unless kind == "Task"
      find("#{panel} input[placeholder='Rapid log…']").fill_in(with: "calendar #{kind.downcase}")
      find("#{panel} input[type='submit'][value='Log']").click
      assert_text "calendar #{kind.downcase}"
    end
    assert_equal %w[task event note],
      @user.entries.monthly_calendar(month).pluck(:kind)

    visit monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks")
    %w[Task Event Note].each do |kind|
      find("#monthly_tasks_capture_reveal").click
      assert_field "Rapid log…"
      find("#monthly_tasks_capture_panel:not([hidden]) button[aria-label='#{kind}']").click unless kind == "Task"
      fill_in "Rapid log…", with: "tasks #{kind.downcase}"
      click_button "Log", exact: true
      assert_text "tasks #{kind.downcase}"
    end
    assert_equal %w[task event note],
      @user.entries.monthly_tasks(month).pluck(:kind)
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def create_entry(overrides = {})
    @user.entries.create!({
      kind: "task", state: "open", text: "entry words", priority: false, tags: [],
      page_kind: "daily", page_on: Time.zone.today
    }.merge(overrides))
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end

  def reveal_actions(entry)
    within(entry_selector(entry)) { find(".entry__toggle").click }
  end

  def row_geometry(entry)
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const row = document.querySelector("#{entry_selector(entry)}")
        const glyph = row.querySelector(".entry__glyph").getBoundingClientRect()
        const text = row.querySelector(".entry__text").getBoundingClientRect()
        const meta = row.querySelector(".entry__meta").getBoundingClientRect()
        return [Math.round(glyph.left), Math.round(text.left), Math.round(meta.right)]
      })()
    JAVASCRIPT
  end

  def structural_attributes(entry)
    entry.reload.attributes.slice(
      "id", "user_id", "page_kind", "page_on", "collection_id", "parent_id",
      "migrated_from_id", "created_at", "deleted_at", "hlc", "server_seq"
    )
  end

  def set_native_date(field, date)
    page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT
  end

  def assert_schedule_geometry
    geometry = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const form = document.querySelector(".entry__schedule")
        const field = form.querySelector("input[type='date']")
        const submit = form.querySelector("input[type='submit']")
        const cancel = form.closest(".entry__schedule-step").querySelector("button")
        const boxes = [form, field, submit, cancel].map((element) => element.getBoundingClientRect())
        return boxes.map((box) => ({
          left: box.left, right: box.right, top: box.top, bottom: box.bottom,
          width: box.width, height: box.height
        }))
      })()
    JAVASCRIPT
    form, field, submit, cancel = geometry
    assert_in_delta form["left"], field["left"], 1
    assert_in_delta form["right"], field["right"], 1
    assert_operator submit["top"], :>=, field["bottom"]
    assert_operator cancel["top"], :>=, field["bottom"]
    [ field, submit, cancel ].each { |box| assert_operator box["height"], :>=, 44 }
  end

  def assert_title_before_alert
    positions = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const title = document.querySelector("main h1")
        const alert = document.querySelector("[role='alert']")
        return {
          source: title.compareDocumentPosition(alert),
          titleTop: title.getBoundingClientRect().top,
          alertTop: alert.getBoundingClientRect().top
        }
      })()
    JAVASCRIPT
    assert_operator positions["source"] & 4, :>, 0
    assert_operator positions["titleTop"], :<, positions["alertTop"]
  end

  def set_preferences(theme:, hand:)
    until page.has_selector?("html[data-theme='#{theme}']", visible: :all, wait: 0.2)
      find("button", text: /Theme:/).click
    end
    until page.has_selector?("html[data-hand='#{hand}']", visible: :all, wait: 0.2)
      find("button", text: /Hand:/).click
    end
  end

  def assert_no_horizontal_overflow
    geometry = page.evaluate_script(<<~JAVASCRIPT)
      ({ scroll: document.documentElement.scrollWidth, viewport: document.documentElement.clientWidth })
    JAVASCRIPT
    assert_operator geometry["scroll"], :<=, geometry["viewport"]
  end
end
