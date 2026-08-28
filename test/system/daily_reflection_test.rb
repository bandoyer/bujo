require "application_system_test_case"

# Exercises the twelve approved Daily Reflection browser flows through the
# same Hotwire, Entry, preference, and navigation surfaces a phone reader uses.
class DailyReflectionTest < ApplicationSystemTestCase
  TODAY = Date.new(2026, 8, 27)
  MONTH = TODAY.beginning_of_month

  setup do
    @user = users(:one)
    @other_user = users(:two)
    @user.entries.update_all(deleted_at: Time.current)
    @other_user.entries.update_all(deleted_at: Time.current)
  end

  test "1 Today alone opens Morning title-first without writing" do
    travel_to TODAY do
      sign_in_through_browser @user
      original = @user.entries.count

      assert_link "Reflect"
      assert_minimum_target(find_link("Reflect"))
      click_link "Reflect"

      assert_current_path reflection_path
      assert_selector "main > h1:first-child", text: "Daily Reflection", count: 1
      assert_selector "h1", count: 1
      assert_text "THURSDAY · AUGUST 27"
      assert_selector ".tab-bar__item--active[aria-current='page']", text: "Today"
      assert_equal original, @user.entries.count

      visit daily_log_path(date: TODAY.prev_day.iso8601)
      assert_no_link "Reflect"
      visit daily_log_path(date: TODAY.next_day.iso8601)
      assert_no_link "Reflect"
    end
  end

  test "2 explicit mode switch alone changes Morning and Evening" do
    travel_to TODAY do
      sign_in_through_browser @user
      click_link "Reflect"

      assert_selector ".daily-reflection__mode[aria-current='page']", text: "Morning"
      assert_text "Plan the day"
      assert_minimum_target(find_link("Evening"))
      click_link "Evening"
      assert_current_path evening_reflection_path
      assert_selector ".daily-reflection__mode[aria-current='page']", text: "Evening"
      assert_text "Review the day"

      refresh
      assert_current_path evening_reflection_path
      visit reflection_path
      assert_selector ".daily-reflection__mode[aria-current='page']", text: "Morning"
      assert_nil page.evaluate_script("document.cookie.match(/reflection/i)")
    end
  end

  test "3 Morning capture writes each kind only to today and preserves refusal" do
    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path

      capture_reflection("overnight task", kind: "Task")
      capture_reflection("overnight event", kind: "Event")
      capture_reflection("overnight note", kind: "Note")

      assert_current_path reflection_path
      assert_equal %w[task event note],
        @user.entries.where(text: [ "overnight task", "overnight event", "overnight note" ])
          .order(:created_at, :id).pluck(:kind)
      assert_equal [ TODAY ],
        @user.entries.where(text: [ "overnight task", "overnight event", "overnight note" ]).distinct.pluck(:page_on)

      choose_reflection_kind("Event")
      fill_in "What surfaced overnight?", with: "-"
      click_button "Log"
      assert_current_path reflection_path
      assert_field "What surfaced overnight?", with: "-"
      assert_selector "button[aria-label='Event'][aria-pressed='true']"
      assert_text "That entry can't do that."
    end
  end

  test "4 Morning shows exact page and tree order with nested context" do
    calendar = create_entry(text: "calendar context", kind: "event", page_kind: "monthly_calendar",
      page_on: MONTH, occurs_on: MONTH + 2.days)
    nested = create_entry(text: "nested open", page_kind: "monthly_calendar", page_on: MONTH,
      occurs_on: MONTH + 2.days, parent: calendar)
    monthly = create_entry(text: "monthly open", page_kind: "monthly_tasks", page_on: MONTH)
    daily = create_entry(text: "daily open", page_kind: "daily", page_on: TODAY.prev_day)
    create_entry(text: "excluded future", page_kind: "future", page_on: nil, occurs_on: TODAY.next_month)
    create_entry(user: @other_user, text: "foreign secret", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path

      [ calendar, nested, monthly, daily ].each { |entry| assert_selector "#entry_#{entry.id}", count: 1 }
      assert_selector "#entry_#{calendar.id} #entry_#{nested.id}"
      assert_no_text "excluded future"
      assert_no_text "foreign secret"
      assert_dom_order("Monthly Calendar · August 2026", "nested open",
        "Monthly Tasks · August 2026", "monthly open", "Daily Log · August 26, 2026", "daily open")
    end
  end

  test "5 priority mark and clear changes only the signifier and keeps order" do
    first = create_entry(text: "first priority", page_kind: "monthly_tasks", page_on: MONTH)
    second = create_entry(text: "second priority", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path
      original_order = all(".entry__text").map(&:text)

      reveal_actions(first)
      within("#entry_#{first.id}") { click_button "Mark priority" }
      assert_current_path reflection_path
      assert_selector "#entry_#{first.id} .entry__signifier", text: "*"
      assert_predicate first.reload, :priority?
      assert_equal original_order, all(".entry__text").map(&:text)

      reveal_actions(first)
      within("#entry_#{first.id}") { click_button "Clear priority" }
      assert_selector "#entry_#{first.id} .entry__signifier[aria-label='Not priority']", visible: :all
      assert_not first.reload.priority?

      first.complete!
      visit reflection_path
      assert_no_selector "#entry_#{first.id}"
      assert_selector "#entry_#{second.id}"
    end
  end

  test "6 Morning empty state remains a live capture surface" do
    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path

      assert_text "No open tasks on this month's pages."
      assert_no_text "planned"
      assert_field "What surfaced overnight?"
      assert_minimum_targets
    end
  end

  test "7 Evening capture returns to the recomputed live Daily list" do
    travel_to TODAY do
      sign_in_through_browser @user
      visit evening_reflection_path
      assert_text "Nothing logged today yet."

      capture_reflection("missed note", kind: "Note", label: "What did you miss?")

      assert_current_path evening_reflection_path
      assert_text "missed note"
      captured = @user.entries.find_by!(text: "missed note")
      assert_equal [ "note", "daily", TODAY ], captured.values_at(:kind, :page_kind, :page_on)
    end
  end

  test "8 Evening Complete Strike and both Schedule branches update in place" do
    complete = create_entry(text: "complete me", page_kind: "daily", page_on: TODAY)
    strike = create_entry(text: "strike me", page_kind: "daily", page_on: TODAY)
    calendar = create_entry(text: "calendar me", page_kind: "daily", page_on: TODAY)
    future = create_entry(text: "future me", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit evening_reflection_path

      reveal_actions(complete)
      within("#entry_#{complete.id}") { click_button "Complete" }
      assert_selector "#entry_#{complete.id} .entry__glyph", text: "x"

      reveal_actions(strike)
      within("#entry_#{strike.id}") { click_button "Strike" }
      assert_selector "#entry_#{strike.id} .entry__text--struck"

      schedule_from_evening(calendar, TODAY + 2.days)
      assert_selector "#entry_#{calendar.id} .entry__glyph", text: ">"
      assert_equal [ "monthly_calendar", MONTH, TODAY + 2.days ],
        calendar.reload.successor.values_at(:page_kind, :page_on, :occurs_on)

      schedule_from_evening(future, TODAY.next_month)
      assert_selector "#entry_#{future.id} .entry__glyph", text: "<"
      assert_equal [ "future", nil, TODAY.next_month ],
        future.reload.successor.values_at(:page_kind, :page_on, :occurs_on)
    end
  end

  test "9 Evening has only its focused command matrix while Today stays broad" do
    task = create_entry(text: "open task", page_kind: "daily", page_on: TODAY)
    event = create_entry(text: "open event", kind: "event", page_kind: "daily", page_on: TODAY)
    note = create_entry(text: "plain note", kind: "note", page_kind: "daily", page_on: TODAY)
    done = create_entry(text: "done task", state: "done", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit evening_reflection_path

      reveal_actions(task)
      within("#entry_#{task.id}") do
        assert_button "Complete"
        assert_button "Strike"
        assert_button "Schedule…"
        assert_no_button "Edit"
        assert_no_button "Migrate"
        assert_no_button "Move to Collection…"
      end
      reveal_actions(event)
      within("#entry_#{event.id}") do
        assert_button "Schedule…"
        assert_no_button "Complete"
      end
      [ note, done ].each { |entry| assert_no_selector "#entry_#{entry.id} .entry__toggle" }

      click_link "Today", exact: true
      assert_current_path root_path
      reveal_actions(task)
      assert_selector "#entry_#{task.id}.entry--selected"
      within("#entry_#{task.id}") do
        assert_button "Edit"
        assert_button "Migrate"
        assert_button "Move to Collection…"
      end
    end
  end

  test "10 completion copy is live derived singular plural and zero" do
    first = create_entry(text: "first done", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit evening_reflection_path
      assert_no_selector ".daily-reflection__progress"
      assert_text "Notice what moved forward today."

      first.complete!
      refresh
      assert_text "1 task marked complete."

      create_entry(text: "second done", state: "done", page_kind: "daily", page_on: TODAY)
      refresh
      assert_text "2 tasks marked complete."
      assert_no_text "%"
      assert_no_button "Finish"
      assert_not ActiveRecord::Base.connection.data_source_exists?("daily_reflections")
    end
  end

  test "11 refresh stale and missing commands create no duplicate or unrelated write" do
    task = create_entry(text: "stale task", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path
      task.complete!
      original_count = Entry.unscoped.count
      submit_post(mark_priority_reflection_path(task))
      assert_current_path reflection_path
      assert_equal original_count, Entry.unscoped.count
      assert_not task.reload.priority?

      missing_id = SecureRandom.uuid
      submit_post(mark_priority_reflection_path(missing_id))
      assert_current_path mark_priority_reflection_path(missing_id)
      assert_no_text "stale task"
      assert_equal original_count, Entry.unscoped.count
    end
  end

  test "12 both modes wrap at phone widths in both themes and two hands" do
    root = create_entry(text: "A very long authored line " * 8, page_kind: "daily", page_on: TODAY,
      priority: true)
    3.times do |index|
      root = create_entry(text: "Nested reflection context #{index} " * 5, kind: "note",
        page_kind: "daily", page_on: TODAY, parent: root)
    end

    travel_to TODAY do
      sign_in_through_browser @user
      [
        [ reflection_path, "light", "rock-salt" ],
        [ evening_reflection_path, "dark", "architects-daughter" ]
      ].each do |path, theme, hand|
        set_preferences(theme: theme, hand: hand)
        [ 390, 320 ].each do |width|
          page.current_window.resize_to(width, 844)
          visit path
          assert_no_horizontal_overflow
          assert_minimum_targets
          assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
          assert_selector ".tab-bar__item--active[aria-current='page']", text: "Today"
          assert_tab_clearance
        end
      end
    end
  end

  private

  def create_entry(user: @user, text:, kind: "task", state: :default, page_kind:, page_on:,
    parent: nil, occurs_on: nil, priority: false)
    user.entries.create!(
      text: text,
      kind: kind,
      state: state == :default ? ("open" if kind == "task") : state,
      tags: [],
      priority: priority,
      page_kind: page_kind,
      page_on: page_on,
      parent: parent,
      occurs_on: occurs_on
    )
  end

  def choose_reflection_kind(kind)
    find("button[aria-label='#{kind}']").click
  end

  def capture_reflection(line, kind:, label: "What surfaced overnight?")
    choose_reflection_kind(kind)
    fill_in label, with: line
    click_button "Log"
    assert_field label, with: ""
  end

  def reveal_actions(entry)
    within("#entry_#{entry.id}") { find(".entry__toggle").click }
  end

  def schedule_from_evening(entry, date)
    reveal_actions(entry)
    within("#entry_#{entry.id}") do
      click_button "Schedule…"
      assert_field "Schedule for"
      set_date_field("Schedule for", date)
      click_button "Schedule", exact: true
    end
  end

  def set_date_field(label, date)
    field = find_field(label)
    page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT
  end

  def assert_dom_order(*texts)
    offsets = texts.map { |text| page.html.index(text) }
    assert offsets.all?
    assert_equal offsets.sort, offsets
  end

  def assert_minimum_target(element)
    box = element.rect
    assert_operator box.width, :>=, 44
    assert_operator box.height, :>=, 44
  end

  def assert_minimum_targets
    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("main a, main button, main input"))
        .filter((element) => {
          if (element.hidden || element.offsetParent === null || element.type === "hidden") return false
          const box = element.getBoundingClientRect()
          return box.width < 44 || box.height < 44
        })
        .map((element) => element.outerHTML)
    JAVASCRIPT
    assert_empty undersized
  end

  def assert_no_horizontal_overflow
    geometry = page.evaluate_script(<<~JAVASCRIPT)
      ({ body: document.body.scrollWidth, viewport: document.documentElement.clientWidth })
    JAVASCRIPT
    assert_operator geometry.fetch("body"), :<=, geometry.fetch("viewport")
  end

  def assert_tab_clearance
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    covered = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const tabs = document.querySelector(".tab-bar").getBoundingClientRect()
        return [...document.querySelectorAll("main > :not(.tab-bar) input, main > :not(.tab-bar) button")]
          .filter((element) => element.offsetParent !== null)
          .filter((element) => {
            const box = element.getBoundingClientRect()
            return box.top < tabs.bottom && box.bottom > tabs.top
          })
          .map((element) => element.outerHTML)
      })()
    JAVASCRIPT
    assert_empty covered
  end

  def set_preferences(theme:, hand:)
    visit reflection_path
    until page.has_selector?("html[data-theme='#{theme}']", visible: :all, wait: 0.2)
      find("button", text: /Theme:/).click
    end
    until page.has_selector?("html[data-hand='#{hand}']", visible: :all, wait: 0.2)
      find("button", text: /Hand:/).click
    end
  end

  def submit_post(path)
    page.execute_script(<<~JAVASCRIPT)
      const form = document.createElement("form")
      form.method = "post"
      form.action = #{path.to_json}
      const token = document.querySelector("meta[name='csrf-token']")
      if (token) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "authenticity_token"
        input.value = token.content
        form.appendChild(input)
      }
      document.body.appendChild(form)
      form.submit()
    JAVASCRIPT
  end
end
