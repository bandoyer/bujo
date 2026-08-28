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
    travel_to TODAY do
      sign_in_through_browser @user
      [
        [ 390, "light", "rock-salt" ],
        [ 320, "light", "architects-daughter" ],
        [ 390, "dark", "architects-daughter" ],
        [ 320, "dark", "rock-salt" ]
      ].each do |width, theme, hand|
        set_preferences(theme: theme, hand: hand)
        page.current_window.resize_to(width, 844)
        @user.entries.update_all(deleted_at: Time.current)

        morning = create_entry(text: "A very long authored Morning line " * 8,
          page_kind: "daily", page_on: TODAY, priority: true)
        root = morning
        3.times do |index|
          root = create_entry(text: "Nested complete reflection context #{index} " * 5,
            kind: "note", page_kind: "daily", page_on: TODAY, parent: root)
        end
        visit reflection_path
        assert_phone_state(theme: theme, hand: hand, mode: "Morning")

        reveal_actions(morning)
        assert_selector ".entry__toggle[aria-expanded='true']"
        within("#entry_#{morning.id}") do
          assert_button "Clear priority", count: 1
          assert_no_button "Mark priority"
        end
        assert_phone_state(theme: theme, hand: hand, mode: "Morning")

        invalid_line = "+#{'preserved-long-tag-' * 8}"
        choose_reflection_kind("Event")
        fill_in "What surfaced overnight?", with: invalid_line
        find_field("What surfaced overnight?").send_keys(:enter)
        assert_field "What surfaced overnight?", with: invalid_line
        assert_selector "button[aria-label='Event'][aria-pressed='true']"
        assert_focused "#reflection_line"
        assert_phone_state(theme: theme, hand: hand, mode: "Morning")

        @user.entries.update_all(deleted_at: Time.current)
        visit reflection_path
        assert_text "No open tasks on this month's pages."
        assert_phone_state(theme: theme, hand: hand, mode: "Morning")

        evening = create_entry(text: "A very long Evening task " * 8,
          page_kind: "daily", page_on: TODAY)
        create_entry(text: "Finished Evening task", state: "done",
          page_kind: "daily", page_on: TODAY)
        child = evening
        3.times do |index|
          child = create_entry(text: "Nested Evening metadata #{index} " * 5, kind: "note",
            page_kind: "daily", page_on: TODAY, parent: child)
        end
        visit evening_reflection_path
        assert_text "1 task marked complete."
        assert_phone_state(theme: theme, hand: hand, mode: "Evening")

        reveal_actions(evening)
        assert_selector ".entry__toggle[aria-expanded='true']"
        within("#entry_#{evening.id}") do
          assert_button "Complete", count: 1
          assert_button "Strike", count: 1
          assert_button "Schedule…", count: 1
          assert_no_button "Edit"
        end
        assert_phone_state(theme: theme, hand: hand, mode: "Evening")

        within("#entry_#{evening.id}") { find_button("Schedule…").send_keys(:enter) }
        assert_focused "#entry_#{evening.id} input[type='date']"
        assert_phone_state(theme: theme, hand: hand, mode: "Evening")

        set_date_field("Schedule for", TODAY)
        within("#entry_#{evening.id}") { find_button("Schedule", exact: true).send_keys(:enter) }
        assert_selector ".flash--alert", text: "That entry can't do that."
        assert_focused "#entry_#{evening.id} .entry__toggle"
        assert_phone_state(theme: theme, hand: hand, mode: "Evening")

        @user.entries.update_all(deleted_at: Time.current)
        visit evening_reflection_path
        assert_text "Nothing logged today yet."
        assert_phone_state(theme: theme, hand: hand, mode: "Evening")
      end
    end
  end

  test "13 keyboard mode navigation focuses the active mode only for its response" do
    travel_to TODAY do
      sign_in_through_browser @user
      click_link "Reflect"

      find_link("Evening").send_keys(:enter)
      assert_current_path evening_reflection_path
      assert_focused ".daily-reflection__mode[aria-current='page']"

      refresh
      assert_not_focused ".daily-reflection__mode[aria-current='page']"
    end
  end

  test "14 keyboard Morning capture returns focus to the cleared or preserved field" do
    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path
      field = find_field("What surfaced overnight?")

      field.fill_in with: "keyboard capture"
      field.send_keys(:enter)
      assert_field "What surfaced overnight?", with: ""
      assert_focused "#reflection_line"

      field = find_field("What surfaced overnight?")
      field.fill_in with: "-"
      field.send_keys(:enter)
      assert_field "What surfaced overnight?", with: "-"
      assert_focused "#reflection_line"
      assert_selector "main > h1:first-child", count: 1
      assert_selector ".flash--alert", text: "That entry can't do that."
    end
  end

  test "15 keyboard Schedule opens on its native date field and Cancel returns to its toggle" do
    task = create_entry(text: "keyboard schedule", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit evening_reflection_path
      toggle = find("#entry_#{task.id} .entry__toggle")
      toggle.send_keys(:enter)
      within("#entry_#{task.id}") { find_button("Schedule…").send_keys(:enter) }

      assert_focused "#entry_#{task.id} input[type='date']"
      assert_selector "#entry_#{task.id}.entry--selected .entry__toggle[aria-expanded='true']"
      within("#entry_#{task.id}") { find_button("Cancel").send_keys(:enter) }
      assert_focused "#entry_#{task.id} .entry__toggle", response: false
      assert_selector "#entry_#{task.id} .entry__toggle[aria-expanded='true']"
      assert_button "Schedule…"
    end
  end

  test "16 command responses focus the changed row, actionable toggle, or mode fallback once" do
    priority = create_entry(text: "keyboard priority", page_kind: "daily", page_on: TODAY)
    complete = create_entry(text: "keyboard complete", page_kind: "daily", page_on: TODAY)
    strike = create_entry(text: "keyboard strike", page_kind: "daily", page_on: TODAY)
    schedule = create_entry(text: "keyboard schedule success", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      visit reflection_path

      keyboard_entry_command(priority, "Mark priority")
      assert_focused "#entry_#{priority.id} .entry__toggle"

      priority.complete!
      find("#entry_#{priority.id} .entry__toggle").send_keys(:enter)
      within("#entry_#{priority.id}") { find_button("Clear priority").send_keys(:enter) }
      assert_focused ".daily-reflection__mode[aria-current='page']"

      visit evening_reflection_path
      activate_entry_command(complete, "Complete")
      assert_focused "#entry_#{complete.id}[tabindex='-1']"
      assert_selector "#entry_#{complete.id} .entry__glyph", text: "x"

      activate_entry_command(strike, "Strike")
      assert_focused "#entry_#{strike.id}[tabindex='-1']"
      assert_selector "#entry_#{strike.id} .entry__text--struck"

      reveal_actions(schedule)
      within("#entry_#{schedule.id}") { find_button("Schedule…").send_keys(:enter) }
      set_date_field("Schedule for", TODAY + 2.days)
      within("#entry_#{schedule.id}") { find_button("Schedule", exact: true).send_keys(:enter) }
      assert_focused "#entry_#{schedule.id}[tabindex='-1']"

      refresh
      assert_no_selector "#entry_#{schedule.id}[autofocus]", visible: :all
      assert_not_focused "#entry_#{schedule.id}"
    end
  end

  test "17 one real keyboard walk settles every Reflection response on a visible target" do
    priority = create_entry(text: "walk priority", page_kind: "daily", page_on: TODAY)
    complete = create_entry(text: "walk complete", page_kind: "daily", page_on: TODAY)
    strike = create_entry(text: "walk strike", page_kind: "daily", page_on: TODAY)
    refused = create_entry(text: "walk refused schedule", page_kind: "daily", page_on: TODAY)
    calendar = create_entry(text: "walk calendar schedule", page_kind: "daily", page_on: TODAY)
    future = create_entry(text: "walk future schedule", page_kind: "daily", page_on: TODAY)

    travel_to TODAY do
      sign_in_through_browser @user
      click_link "Reflect"

      keyboard_tab_to("#reflection_evening_mode")
      keyboard_activate
      assert_focused "#reflection_evening_mode"
      keyboard_tab_to("#reflection_morning_mode")
      keyboard_activate
      assert_focused "#reflection_morning_mode"

      keyboard_tab_to("#reflection_line")
      keyboard_type_and_submit("walk Morning capture")
      assert_field "What surfaced overnight?", with: ""
      assert_focused "#reflection_line"

      keyboard_tab_to("button[aria-label='Event']")
      keyboard_activate
      keyboard_tab_to("#reflection_line")
      keyboard_type_and_submit("-")
      assert_field "What surfaced overnight?", with: "-"
      assert_selector "button[aria-label='Event'][aria-pressed='true']"
      assert_focused "#reflection_line"

      keyboard_entry_command(priority, "Mark priority")
      assert_selector "#entry_#{priority.id} .entry__signifier[aria-label='Priority']"
      assert_focused "#entry_#{priority.id} .entry__toggle"
      keyboard_entry_command(priority, "Clear priority")
      assert_selector "#entry_#{priority.id} .entry__signifier[aria-label='Not priority']", visible: :all
      assert_focused "#entry_#{priority.id} .entry__toggle"

      keyboard_tab_to("#reflection_evening_mode")
      keyboard_activate
      assert_focused "#reflection_evening_mode"

      keyboard_entry_command(complete, "Complete")
      assert_focused "#entry_#{complete.id}[tabindex='-1']"
      keyboard_entry_command(strike, "Strike")
      assert_focused "#entry_#{strike.id}[tabindex='-1']"

      keyboard_entry_command(refused, "Schedule…")
      assert_focused "#entry_#{refused.id} input[type='date']"
      within("#entry_#{refused.id}") { find_button("Cancel").send_keys(:enter) }
      assert_focused "#entry_#{refused.id} .entry__toggle", response: false
      within("#entry_#{refused.id}") { find_button("Schedule…").send_keys(:enter) }
      assert_focused "#entry_#{refused.id} input[type='date']"
      set_date_field("Schedule for", TODAY)
      within("#entry_#{refused.id}") { find_button("Schedule", exact: true).send_keys(:enter) }
      assert_focused "#entry_#{refused.id} .entry__toggle"
      assert_nil refused.reload.successor

      keyboard_schedule(calendar, TODAY + 2.days)
      assert_focused "#entry_#{calendar.id}[tabindex='-1']"
      assert_equal "monthly_calendar", calendar.reload.successor.page_kind
      keyboard_schedule(future, TODAY.next_month)
      assert_focused "#entry_#{future.id}[tabindex='-1']"
      assert_equal "future", future.reload.successor.page_kind

      keyboard_tab_to("#reflection_line")
      keyboard_type_and_submit("walk Evening capture")
      assert_field "What did you miss?", with: ""
      assert_focused "#reflection_line"
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

  def assert_phone_state(theme:, hand:, mode:)
    assert_no_horizontal_overflow
    assert_minimum_targets
    assert_selector "main > h1:first-child", text: "Daily Reflection", count: 1
    assert_selector "h1", count: 1
    assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
    assert_selector ".daily-reflection__mode[aria-current='page']", text: mode
    assert_selector ".tab-bar__item--active[aria-current='page']", text: "Today"
    assert_visible_copy_is_not_clipped
    assert_selected_hand_font(hand)
    assert_tab_clearance
  end

  def assert_visible_copy_is_not_clipped
    clipped = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll(".entry__text, .entry__meta, .daily-reflection__source-link, label, .action"))
        .filter((element) => element.offsetParent !== null)
        .filter((element) => element.scrollWidth > element.clientWidth + 1)
        .map((element) => element.outerHTML)
    JAVASCRIPT
    assert_empty clipped
  end

  def assert_selected_hand_font(hand)
    expected = { "rock-salt" => "Rock Salt", "architects-daughter" => "Architects Daughter" }.fetch(hand)
    wrong = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const expected = #{expected.to_json}
        return Array.from(document.querySelectorAll(
          "h1, .daily-reflection__mode, .rapid-log__label, #reflection_line, .rapid-log__submit, " +
          ".entry__text, .entry-action, .flash, .tab-bar__item"
        ))
          .filter((element) => element.offsetParent !== null)
          .filter((element) => !getComputedStyle(element).fontFamily.includes(expected))
          .map((element) => `${element.tagName}.${element.className}: ${getComputedStyle(element).fontFamily}`)
      })()
    JAVASCRIPT
    assert_empty wrong
  end

  def activate_entry_command(entry, label)
    toggle = find("#entry_#{entry.id} .entry__toggle")
    toggle.send_keys(:enter)
    within("#entry_#{entry.id}") { find_button(label).send_keys(:enter) }
  end

  def keyboard_tab_to(selector)
    50.times do
      return if page.evaluate_script("document.activeElement.matches(#{selector.to_json})")

      page.driver.browser.action.send_keys(:tab).perform
    end
    flunk "Could not reach #{selector} with Tab"
  end

  def keyboard_activate
    page.driver.browser.action.send_keys(:enter).perform
  end

  def keyboard_type_and_submit(text)
    page.driver.browser.action.send_keys(text).send_keys(:enter).perform
  end

  def keyboard_schedule(entry, date)
    keyboard_entry_command(entry, "Schedule…")
    assert_focused "#entry_#{entry.id} input[type='date']"
    set_date_field("Schedule for", date)
    within("#entry_#{entry.id}") { find_button("Schedule", exact: true).send_keys(:enter) }
  end

  def keyboard_entry_command(entry, label)
    keyboard_tab_to("#entry_#{entry.id} .entry__toggle")
    keyboard_activate
    assert_selector "#entry_#{entry.id} .entry__toggle[aria-expanded='true']"
    keyboard_tab_to_named("#entry_#{entry.id} .entry-action", label)
    keyboard_activate
  end

  def keyboard_tab_to_named(selector, label)
    50.times do
      matches = page.evaluate_script(<<~JAVASCRIPT)
        document.activeElement.matches(#{selector.to_json}) &&
          document.activeElement.textContent.trim() === #{label.to_json}
      JAVASCRIPT
      return if matches

      page.driver.browser.action.send_keys(:tab).perform
    end
    flunk "Could not reach #{label} with Tab"
  end

  def assert_focused(selector, response: true)
    assert_selector "#{selector}[autofocus]", visible: :all if response
    find(selector)
    focused = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
    assert focused, "Expected #{selector} to own focus"
    outline = page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")
    assert_not_equal "none", outline
  end

  def assert_not_focused(selector)
    refute page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
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
