require "application_system_test_case"

# Pins the shared Entry row and command-strip presentation independently from
# the Daily and Collection page compositions that host it.
class TailwindEntriesTest < ApplicationSystemTestCase
  PROFILES = [
    { width: 390, theme: "light", hand: "rock-salt" },
    { width: 320, theme: "dark", hand: "architects-daughter" }
  ].freeze

  setup do
    @user = users(:one)
    @today = Date.new(2026, 8, 27)
    travel_to Time.zone.local(2026, 8, 27, 12)
    @user.entries.update_all(deleted_at: Time.current)
    @user.collections.update_all(deleted_at: Time.current)
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
    travel_back
  end

  test "row anatomy wraps complete text and destination metadata without losing either track" do
    long_topic = "ExpeditionPlansForEveryCampsiteTrailheadWaterSourcePermitDeadlineAndEmergencyContact"
    long_text = "ReaderAuthoredEntryWordsStayCompleteEvenWhenThisSingleUnbrokenStringMustShareTheRowWithDestinationMetadata"
    destination = @user.collections.create!(name: long_topic)
    predecessor = create_entry(text: long_text, kind: "note", state: nil, priority: true)
    predecessor.move_to!(page_kind: "collection", page_on: nil, collection: destination, as_of: @today)
    child = create_entry(text: "nested context", kind: "note", state: nil, parent: predecessor)
    sign_in

    PROFILES.each do |profile|
      visit daily_log_path(date: @today.iso8601)
      apply_profile(**profile)

      within entry_selector(predecessor) do
        assert_selector ":scope > .entry__line > .entry__signifier", text: "*", exact_text: true
        assert_selector ":scope > .entry__line > .entry__glyph", text: ">", exact_text: true
        assert_selector ":scope > .entry__line > .entry__text", text: long_text, exact_text: true
        assert_selector ":scope > .entry__line > .entry__meta", text: "→ #{long_topic}", exact_text: true
        assert_selector ":scope > .entry__children > #{entry_selector(child)} > .entry__line",
          text: "nested context", exact_text: false
      end

      geometry = entry_geometry(predecessor)
      assert_equal 4, geometry.fetch("columns").split.size
      assert_operator geometry.dig("text", "width"), :>, 0
      assert_operator geometry.dig("meta", "width"), :>, 0
      assert_operator geometry.dig("text", "right"), :<=, geometry.dig("meta", "x")
      assert_operator geometry.dig("meta", "width"), :<=, geometry.dig("line", "width") * 0.46
      assert_wrapped_complete("#{entry_selector(predecessor)} > .entry__line > .entry__text", long_text)
      assert_wrapped_complete("#{entry_selector(predecessor)} > .entry__line > .entry__meta", "→ #{long_topic}")
      assert_in_delta geometry.dig("line", "x") + 24, geometry.fetch("childLineX"), 0.75
      assert_no_horizontal_overflow
    end
  end

  test "Task Event Note and lifecycle rows keep glyph ink metadata and command matrix" do
    destination = @user.collections.create!(name: "Archive Topic")
    task = create_entry(text: "open task", priority: true, time_of_day: "08:05", tags: %w[home])
    event = create_entry(text: "dated event", kind: "event", state: nil, occurs_on: @today, time_of_day: "14:30")
    note = create_entry(text: "plain note", kind: "note", state: nil)
    done = create_entry(text: "done task").tap(&:complete!)
    struck = create_entry(text: "struck task").tap(&:strike!)
    migrated = create_entry(text: "migrated task")
    migrated.move_to!(page_kind: "monthly_tasks", page_on: @today.next_month.beginning_of_month, as_of: @today)
    scheduled = create_entry(text: "scheduled task")
    scheduled.move_to!(page_kind: "future", page_on: nil, occurs_on: @today.next_month + 3.days, as_of: @today)
    collection_task = destination.entries.create!(
      user: @user, kind: "task", state: "open", text: "collection task", tags: [],
      page_kind: "collection", page_on: nil
    )
    collection_note = destination.entries.create!(
      user: @user, kind: "note", state: nil, text: "collection note", tags: [],
      page_kind: "collection", page_on: nil
    )
    sign_in

    PROFILES.each do |profile|
      visit daily_log_path(date: @today.iso8601)
      apply_profile(**profile)
      assert_row(task, glyph: "•",
        commands: [ "Edit", "Complete", "Strike", "Migrate", "Schedule…", "Move to Collection…" ])
      assert_row(event, glyph: "O", commands: [ "Edit", "Schedule…", "Move to Collection…" ])
      assert_row(note, glyph: "–", commands: [ "Edit", "Move to Collection…" ])
      assert_row(done, glyph: "x", commands: %w[Edit Reopen])
      assert_row(struck, glyph: "•", commands: %w[Edit Reopen])
      assert_selector "#{entry_selector(struck)} .entry__text--struck", text: "struck task"
      assert_lifecycle_ink(struck)
      assert_static_row(migrated, glyph: ">")
      assert_static_row(scheduled, glyph: "<")

      visit collection_path(destination)
      apply_profile(**profile)
      assert_row(collection_task, glyph: "•", commands: %w[Edit Complete Strike])
      assert_row(collection_note, glyph: "–", commands: %w[Edit])
      assert_no_horizontal_overflow
    end
  end

  test "revealed selected and command steps preserve origins truthful state focus and target size" do
    first_entry = create_entry(
      text: "ThisLongActionableEntryWrapsWithoutMovingItsColumnsWhileCommandsChange",
      tags: %w[long-metadata]
    )
    second_entry = create_entry(text: "second actionable task")
    @user.collections.create!(name: "Camping Plans")
    sign_in

    PROFILES.each do |profile|
      visit daily_log_path(date: @today.iso8601)
      apply_profile(**profile)
      origins = entry_origins(first_entry)
      strip_id = "entry_#{first_entry.id}_actions"

      within entry_selector(first_entry) do
        assert_selector ".entry__toggle[aria-expanded='false'][aria-controls='#{strip_id}']"
        assert_selector ".entry__action-strip[hidden]", visible: :all
        find(".entry__toggle").click
        assert_selector ".entry__toggle[aria-expanded='true']"
        assert_selector ".entry__action-strip:not([hidden])"
      end
      assert_selector "#{entry_selector(first_entry)}.entry--selected"
      assert_equal origins, entry_origins(first_entry)
      assert_minimum_entry_targets(first_entry)

      within entry_selector(first_entry) do
        click_button "Edit", exact: true
        assert_field "Edit entry", focused: true
        assert_equal origins, entry_origins(first_entry)
        click_button "Cancel", exact: true
        assert_toggle_focus(first_entry)

        click_button "Schedule…", exact: true
        field = find_field("Schedule for")
        assert_equal "date", field[:type]
        assert_equal "", field.value
        assert_operator field.rect.height, :>=, 44
        set_native_date(field, @today.next_month.beginning_of_month)
        assert_equal @today.next_month.beginning_of_month.iso8601, field.value
        assert_equal origins, entry_origins(first_entry)
        click_button "Cancel", exact: true
        assert_toggle_focus(first_entry)

        click_button "Move to Collection…", exact: true
        assert_field "Exact Topic"
        assert_equal origins, entry_origins(first_entry)
        find("button[aria-label='Cancel moving to Collection']").click
        assert_toggle_focus(first_entry)
      end

      within(entry_selector(second_entry)) { find(".entry__toggle").click }
      assert_selector "#{entry_selector(second_entry)}.entry--selected .entry__toggle[aria-expanded='true']"
      assert_no_selector "#{entry_selector(first_entry)}.entry--selected"
      assert_selector "#{entry_selector(first_entry)} .entry__action-strip[hidden]", visible: :all
      assert_equal origins, entry_origins(first_entry)
      assert_no_horizontal_overflow
    end
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def create_entry(overrides = {})
    @user.entries.create!({
      kind: "task", state: "open", text: "entry words", priority: false, tags: [],
      page_kind: "daily", page_on: @today
    }.merge(overrides))
  end

  def apply_profile(width:, theme:, hand:)
    page.current_window.resize_to(width, 844)
    chrome = page.evaluate_script(<<~JAVASCRIPT)
      ({ height: window.outerHeight - window.innerHeight })
    JAVASCRIPT
    page.current_window.resize_to(width, 844 + chrome.fetch("height"))
    page.execute_script(<<~JAVASCRIPT, theme, hand)
      const browserProfile = document.createElement("style")
      browserProfile.textContent = "html { scrollbar-width: none } ::-webkit-scrollbar { width: 0 }"
      document.head.appendChild(browserProfile)
      document.documentElement.dataset.theme = arguments[0]
      document.documentElement.dataset.hand = arguments[1]
    JAVASCRIPT
    page.driver.browser.execute_async_script(<<~JAVASCRIPT)
      const done = arguments[arguments.length - 1]
      document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
    JAVASCRIPT
  end

  def entry_selector(entry)
    "#entry_#{entry.id}"
  end

  def assert_row(entry, glyph:, commands:)
    within entry_selector(entry) do
      assert_selector ":scope > .entry__toggle > .entry__glyph", text: glyph, exact_text: true
      find(".entry__toggle").click
      commands.each { |command| assert_button command, exact: true }
      all_commands = [ "Edit", "Complete", "Strike", "Migrate", "Reopen", "Schedule…", "Move to Collection…" ]
      (all_commands - commands).each do |command|
        assert_no_button command, exact: true
      end
    end
  end

  def assert_static_row(entry, glyph:)
    within entry_selector(entry) do
      assert_selector ":scope > .entry__line:not(.entry__toggle) > .entry__glyph", text: glyph, exact_text: true
      assert_no_selector ".entry__toggle"
      assert_no_selector ".entry__action-strip", visible: :all
    end
  end

  def assert_lifecycle_ink(entry)
    ink = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const row = document.querySelector("#{entry_selector(entry)}")
        const text = getComputedStyle(row.querySelector(".entry__text"))
        const glyph = getComputedStyle(row.querySelector(".entry__glyph"))
        return { color: text.color, decorationColor: text.textDecorationColor,
          thickness: parseFloat(text.textDecorationThickness), glyphDecoration: glyph.textDecorationLine }
      })()
    JAVASCRIPT
    assert_equal ink.fetch("color"), ink.fetch("decorationColor")
    assert_operator ink.fetch("thickness"), :>=, 2
    assert_equal "none", ink.fetch("glyphDecoration")
  end

  def entry_geometry(entry)
    child_selector = "#{entry_selector(entry)} > .entry__children > .entry > .entry__line"
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const row = document.querySelector("#{entry_selector(entry)}")
        const line = row.querySelector(":scope > .entry__line")
        const text = line.querySelector(".entry__text")
        const meta = line.querySelector(".entry__meta")
        const rect = (element) => element.getBoundingClientRect().toJSON()
        return { line: rect(line), text: rect(text), meta: rect(meta),
          columns: getComputedStyle(line).gridTemplateColumns,
          childLineX: document.querySelector("#{child_selector}").getBoundingClientRect().x }
      })()
    JAVASCRIPT
  end

  def entry_origins(entry)
    page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const row = document.querySelector("#{entry_selector(entry)}")
        return [".entry__signifier", ".entry__glyph", ".entry__text", ".entry__meta"].map((selector) => {
          const rect = row.querySelector(":scope > .entry__line " + selector).getBoundingClientRect()
          return [Math.round(rect.x * 4) / 4, Math.round(rect.y * 4) / 4]
        })
      })()
    JAVASCRIPT
  end

  def assert_wrapped_complete(selector, expected_text)
    layout = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const element = document.querySelector(#{selector.to_json})
        const range = document.createRange()
        range.selectNodeContents(element)
        return { text: element.textContent.trim(), lines: new Set(
          Array.from(range.getClientRects()).map((rect) => Math.round(rect.top))
        ).size, scrollWidth: element.scrollWidth, clientWidth: element.clientWidth,
          scrollHeight: element.scrollHeight, clientHeight: element.clientHeight,
          overflow: getComputedStyle(element).overflow,
          textOverflow: getComputedStyle(element).textOverflow }
      })()
    JAVASCRIPT
    assert_equal expected_text, layout.fetch("text")
    assert_operator layout.fetch("lines"), :>, 1
    assert_operator layout.fetch("scrollWidth"), :<=, layout.fetch("clientWidth") + 1
    assert_operator layout.fetch("scrollHeight"), :<=, layout.fetch("clientHeight") + 1
    assert_equal "visible", layout.fetch("overflow")
    assert_not_equal "ellipsis", layout.fetch("textOverflow")
  end

  def assert_minimum_entry_targets(entry)
    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("#{entry_selector(entry)} button, #{entry_selector(entry)} input:not([type='hidden'])"))
        .filter((element) => {
          const rect = element.getBoundingClientRect()
          return rect.width > 0 && rect.height > 0 && (rect.width < 44 || rect.height < 44)
        })
        .map((element) => element.textContent.trim() || element.getAttribute("aria-label"))
    JAVASCRIPT
    assert_empty undersized, "Entry targets below 44px: #{undersized.inspect}"
  end

  def assert_toggle_focus(entry)
    assert page.evaluate_script("document.activeElement === document.querySelector('#{entry_selector(entry)} .entry__toggle')")
  end

  def set_native_date(field, date)
    page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT
  end

  def assert_no_horizontal_overflow
    geometry = page.evaluate_script(<<~JAVASCRIPT)
      ({ scroll: document.documentElement.scrollWidth, viewport: document.documentElement.clientWidth })
    JAVASCRIPT
    assert_operator geometry.fetch("scroll"), :<=, geometry.fetch("viewport")
  end
end
