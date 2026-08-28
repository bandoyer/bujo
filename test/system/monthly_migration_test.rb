require "application_system_test_case"

# Exercises the one-at-a-time ritual through the phone interface, including
# its transient second steps and live completion behavior.
class MonthlyMigrationTest < ApplicationSystemTestCase
  TARGET_MONTH = Time.zone.today.next_month.beginning_of_month
  SOURCE_MONTH = TARGET_MONTH.prev_month

  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
  end

  test "1 next-month setup captures task inventory while the ordinary page stays closed" do
    sign_in
    visit monthly_log_path(month: month_param(TARGET_MONTH), view: "tasks")

    assert_link "Monthly Migration", href: migration_path
    assert_no_selector "[data-page-capture='monthly_tasks']"
    click_link "Monthly Migration"

    assert_current_path migration_path
    assert_title_first
    assert_text month_context
    assert_text "Fresh mental inventory"
    assert_text "Nothing in #{TARGET_MONTH.strftime('%B')} Tasks yet."
    fill_in "What matters this month?", with: "* reserve campsite +travel"
    click_button "Log task"

    assert_current_path migration_path
    assert_text "reserve campsite"
    captured = @user.entries.find_by!(text: "reserve campsite")
    assert_equal [ "task", "open", "monthly_tasks", TARGET_MONTH, true, %w[travel] ],
      captured.values_at(:kind, :state, :page_kind, :page_on, :priority, :tags)

    fill_in "What matters this month?", with: "- not a monthly task"
    click_button "Log task"
    assert_text "That entry can't do that."
    assert_equal "Monthly Migration", page.all("h1, .flash", minimum: 1).first.text
    assert_field "What matters this month?", with: "- not a monthly task"
  end

  test "2 nested outgoing tasks review one tree at a time and resume from Entry state" do
    root = create_entry(
      text: "plan camping", kind: "note", state: nil,
      page_kind: "daily", page_on: SOURCE_MONTH + 13.days
    )
    first = create_entry(
      text: "compare sites", page_kind: "daily", page_on: SOURCE_MONTH + 13.days, parent: root
    )
    context = create_entry(
      text: "ask ranger", kind: "note", state: nil, page_kind: "daily",
      page_on: SOURCE_MONTH + 13.days, parent: root
    )
    second = create_entry(
      text: "pack tent", page_kind: "daily", page_on: SOURCE_MONTH + 14.days
    )
    sign_in
    visit migration_outgoing_path

    assert_title_first
    assert_text "Review outgoing tasks"
    assert_text "Daily Log · #{(SOURCE_MONTH + 13.days).strftime('%B %-d, %Y')}"
    within "#entry_#{root.id}" do
      assert_text "plan camping"
      assert_text "compare sites"
      assert_text "ask ranger"
    end
    assert_selector "#entry_#{first.id}[aria-label='Review this task']"
    assert_no_selector "#entry_#{root.id} > .monthly-migration__actions"
    assert_no_selector "#entry_#{context.id} > .monthly-migration__actions"
    click_button "Strike"

    assert_current_path migration_outgoing_path
    assert_selector ".monthly-migration__candidate[aria-label='Review this task']", text: second.text
    visit monthly_log_path(month: month_param(SOURCE_MONTH), view: "tasks")
    visit migration_outgoing_path
    assert_selector ".monthly-migration__candidate[aria-label='Review this task']", text: second.text

    click_button target_tasks_label
    assert_current_path migration_outgoing_path
    assert_text "No unresolved outgoing tasks."
  end

  test "3 outgoing Collection and Future second steps cancel, refuse, and append one successor" do
    collection = Collection.create_for(user: @user, topic: "Camping Plans")
    to_collection = create_entry(text: "collect permits", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    to_future = create_entry(text: "book opening day", page_kind: "daily", page_on: SOURCE_MONTH + 5.days)
    sign_in
    visit migration_outgoing_path

    click_button "Collection…"
    assert_selector "button[aria-expanded='true'][aria-controls='migration_collection_step']"
    assert_field "Exact Topic"
    find("button[aria-label='Cancel moving to Collection']").click
    assert_no_field "Exact Topic"
    click_button "Collection…"
    fill_in "Exact Topic", with: "Unknown Topic"
    click_button "Move"
    assert_text "That entry can't do that."
    assert_nil to_collection.reload.successor

    click_button "Collection…"
    fill_in "Exact Topic", with: collection.name
    click_button "Move"
    assert_selector ".monthly-migration__candidate[aria-label='Review this task']", text: to_future.text
    collection_successor = @user.entries.find_by!(migrated_from_id: to_collection.id)
    assert_equal collection, collection_successor.collection

    click_button "Future…"
    assert_field "Schedule date"
    set_date_field "Schedule date", TARGET_MONTH.end_of_month
    assert_field "Schedule date", with: TARGET_MONTH.end_of_month.iso8601
    click_button "Schedule"
    assert_text "That entry can't do that."
    assert_nil to_future.reload.successor

    click_button "Future…"
    set_date_field "Schedule date", TARGET_MONTH.next_month
    click_button "Schedule"
    assert_current_path migration_outgoing_path
    assert_text "No unresolved outgoing tasks."
    click_link "Scan the Future Log"
    assert_text "Nothing due for #{TARGET_MONTH.strftime('%B')}."
    assert_no_text "Monthly Migration complete"
    click_link "Finish Monthly Migration"
    assert_text "Monthly Migration complete"
    future_successor = @user.entries.find_by!(migrated_from_id: to_future.id)
    assert_equal [ "future", TARGET_MONTH.next_month ],
      future_successor.values_at(:page_kind, :occurs_on)
  end

  test "4 exact target Future tasks and events use distinct controls and finish live" do
    task = create_entry(
      text: "future task", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 3.days
    )
    event = create_entry(
      text: "campground opens", kind: "event", state: nil,
      page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 7.days, time_of_day: "09:00"
    )
    create_entry(text: "overdue stays future", page_kind: "future", page_on: nil, occurs_on: SOURCE_MONTH + 4.days)
    create_entry(text: "later stays future", page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH.next_month + 4.days)
    sign_in
    visit migration_future_path

    within "#entry_#{task.id}" do
      assert_button target_tasks_label
      assert_button "Strike"
      assert_no_button target_calendar_label
      click_button target_tasks_label
    end
    assert_selector "#entry_#{event.id}"
    task_successor = @user.entries.find_by!(migrated_from_id: task.id)
    assert_equal [ "monthly_tasks", nil ], task_successor.values_at(:page_kind, :occurs_on)

    within "#entry_#{event.id}" do
      assert_button target_calendar_label
      assert_no_button target_tasks_label
      assert_no_button "Strike"
      click_button target_calendar_label
    end
    assert_current_path migration_future_path
    assert_text "Nothing due for #{TARGET_MONTH.strftime('%B')}."
    assert_no_text "Monthly Migration complete"
    click_link "Finish Monthly Migration"
    assert_current_path migration_complete_path
    assert_text "Monthly Migration complete"
    assert_link "#{TARGET_MONTH.strftime('%B')} Calendar"
    assert_link "#{TARGET_MONTH.strftime('%B')} Tasks"
    assert_nil event.reload.state
    event_successor = @user.entries.find_by!(migrated_from_id: event.id)
    assert_equal [ "monthly_calendar", event.occurs_on, "09:00", nil ],
      event_successor.values_at(:page_kind, :occurs_on, :time_of_day, :state)

    appeared_later = create_entry(text: "new source work", page_kind: "daily", page_on: SOURCE_MONTH + 20.days)
    visit migration_complete_path
    assert_current_path migration_outgoing_path
    assert_selector "#entry_#{appeared_later.id}[aria-label='Review this task']"
  end

  test "5 stale missing and cross-tenant actions disclose nothing and never duplicate" do
    candidate = create_entry(text: "stale task", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    foreign = create_entry(
      user: users(:two), text: "foreign journal secret", page_kind: "monthly_tasks", page_on: SOURCE_MONTH
    )
    sign_in
    visit migration_outgoing_path
    candidate.strike!

    click_button "Strike"
    assert_text "That entry can't do that."
    assert_text "Nothing due for #{TARGET_MONTH.strftime('%B')}."
    assert_no_text "Monthly Migration complete"
    assert_equal 1, @user.entries.where(id: candidate.id).count

    submit_post strike_monthly_migration_outgoing_path(month: month_param(TARGET_MONTH), id: foreign)
    assert_text "Migration item not found"
    assert_no_text "foreign journal secret"
    assert_active_month_tab
  end

  test "6 ritual states remain usable at 390 and 320 in both themes and hands" do
    candidate = create_entry(
      text: "ThisUnbrokenMigrationTaskNameMustWrapWithoutMakingTheJournalWiderThanThePhoneViewport",
      page_kind: "daily", page_on: SOURCE_MONTH + 1.day
    )
    sign_in

    [
      [ 390, "light", "rock-salt" ],
      [ 320, "dark", "architects-daughter" ]
    ].each do |width, theme, hand|
      page.current_window.resize_to(width, 844)
      visit migration_outgoing_path
      set_preferences(theme:, hand:)
      visit migration_outgoing_path
      click_button "Collection…"

      assert_equal theme, page.find("html", visible: :all)["data-theme"]
      assert_equal hand, page.find("html", visible: :all)["data-hand"]
      assert_active_month_tab
      assert_no_horizontal_overflow
      assert_minimum_target_sizes
      assert_selector "#entry_#{candidate.id}[aria-label='Review this task']"
      assert_field "Exact Topic"
      assert_selector "button[aria-expanded='true']"
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "outgoing Strike Undo reopens the same task" do
    outgoing = create_entry(text: "undo outgoing strike", page_kind: "monthly_tasks", page_on: SOURCE_MONTH)
    original_count = @user.entries.count
    sign_in
    visit migration_outgoing_path

    click_button "Strike"
    assert_selector ".monthly-migration__confirmation", text: "Struck."
    click_button "Undo"

    assert_undo_offer_consumed
    assert_equal original_count, @user.entries.count
    assert_equal "open", outgoing.reload.state
    assert_nil outgoing.successor
    assert_selector "#entry_#{outgoing.id}[aria-label='Review this task']"
  end

  test "outgoing target Tasks Undo appends an exact source restoration" do
    outgoing = create_entry(
      text: "undo outgoing tasks", priority: true, tags: %w[kept],
      page_kind: "daily", page_on: SOURCE_MONTH + 7.days
    )
    sign_in
    visit migration_outgoing_path

    click_button target_tasks_label
    assert_selector ".monthly-migration__confirmation", text: "Moved to #{target_tasks_label}."
    assert_movement_undo(outgoing, expected_source: [ "daily", SOURCE_MONTH + 7.days, nil, nil, nil ])
  end

  test "outgoing exact-Topic Collection Undo appends an exact source restoration" do
    collection = Collection.create_for(user: @user, topic: "Undo Topic")
    outgoing = create_entry(
      text: "undo outgoing collection", page_kind: "monthly_tasks", page_on: SOURCE_MONTH
    )
    sign_in
    visit migration_outgoing_path

    click_button "Collection…", exact: true
    fill_in "Exact Topic", with: collection.name
    click_button "Move", exact: true
    assert_selector ".monthly-migration__confirmation", text: "Moved to #{collection.name}."
    assert_equal collection, outgoing.reload.successor.collection
    assert_movement_undo(outgoing, expected_source: [ "monthly_tasks", SOURCE_MONTH, nil, nil, nil ])
  end

  test "outgoing Future-date Undo appends an exact source restoration" do
    outgoing = create_entry(
      text: "undo outgoing future", occurs_on: SOURCE_MONTH + 8.days, time_of_day: "07:40",
      page_kind: "monthly_calendar", page_on: SOURCE_MONTH
    )
    scheduled_on = TARGET_MONTH.next_month + 2.days
    sign_in
    visit migration_outgoing_path

    click_button "Future…", exact: true
    set_date_field "Schedule date", scheduled_on
    click_button "Schedule", exact: true
    assert_selector ".monthly-migration__confirmation", text: "Moved to Future · #{scheduled_on.strftime('%b %-d')}."
    assert_movement_undo(
      outgoing,
      expected_source: [ "monthly_calendar", SOURCE_MONTH, nil, SOURCE_MONTH + 8.days, "07:40" ]
    )
  end

  test "due Future task Strike Undo reopens the same task" do
    task = create_entry(
      text: "undo future strike", page_kind: "future", page_on: nil,
      occurs_on: TARGET_MONTH + 3.days
    )
    original_count = @user.entries.count
    sign_in
    visit migration_future_path

    click_button "Strike"
    assert_selector ".monthly-migration__confirmation", text: "Struck."
    click_button "Undo"

    assert_undo_offer_consumed
    assert_equal original_count, @user.entries.count
    assert_equal "open", task.reload.state
    assert_nil task.successor
    assert_selector "#entry_#{task.id}[aria-label='Review this task']"
  end

  test "due Future task target Tasks Undo restores its date and time" do
    task = create_entry(
      text: "undo future tasks", priority: true, tags: %w[trip],
      page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 5.days,
      time_of_day: "08:25"
    )
    sign_in
    visit migration_future_path

    click_button target_tasks_label
    assert_selector ".monthly-migration__confirmation", text: "Moved to #{target_tasks_label}."
    assert_movement_undo(
      task,
      expected_source: [ "future", nil, nil, TARGET_MONTH + 5.days, "08:25" ]
    )
  end

  test "due Future event target Calendar Undo restores exact NULL-state Future placement" do
    event = create_entry(
      text: "undo future event", kind: "event", state: nil, priority: true, tags: %w[opening],
      page_kind: "future", page_on: nil, occurs_on: TARGET_MONTH + 4.days,
      time_of_day: "10:15"
    )
    sign_in
    visit migration_future_path

    click_button target_calendar_label
    assert_selector ".monthly-migration__confirmation", text: "Moved to #{target_calendar_label}."
    assert_movement_undo(
      event,
      expected_source: [ "future", nil, nil, TARGET_MONTH + 4.days, "10:15" ],
      expected_kind_state: [ "event", nil ]
    )
  end

  test "stale second-tab Undo refuses below the title and preserves the resolved successor" do
    outgoing = create_entry(
      text: "stale cross-tab undo", page_kind: "monthly_tasks", page_on: SOURCE_MONTH
    )
    sign_in
    visit migration_outgoing_path
    click_button target_tasks_label
    assert_selector ".monthly-migration__confirmation", text: "Moved to #{target_tasks_label}."
    moved = outgoing.reload.successor
    assert moved

    first_tab = page.current_window
    second_tab = open_new_window
    within_window(second_tab) do
      visit monthly_log_path(month: month_param(TARGET_MONTH), view: "tasks")
      within("#entry_#{moved.id}") do
        find(".entry__toggle").click
        click_button "Complete", exact: true
      end
      assert_selector "#entry_#{moved.id} .entry__glyph", text: "x"
      assert_equal "done", moved.reload.state
    end

    within_window(first_tab) do
      click_button "Undo"
      assert_current_path migration_future_path
      assert_title_first
      assert_selector "[role='alert']", text: "That entry can't do that."
      assert_operator find("h1").rect.y, :<, find("[role='alert']").rect.y
      assert_no_selector ".monthly-migration__confirmation"
    end

    assert_equal "done", moved.reload.state
    assert_nil moved.successor
    assert_equal 2, @user.entries.where(text: outgoing.text).count
  ensure
    second_tab&.close
  end


  test "empty ritual checkpoints require Scan and Finish gestures" do
    sign_in

    [
      [ 390, "light", "rock-salt" ],
      [ 320, "dark", "architects-daughter" ]
    ].each do |width, theme, hand|
      page.current_window.resize_to(width, 844)
      visit migration_path
      set_preferences(theme:, hand:)

      click_link "Review outgoing tasks"
      assert_current_path migration_outgoing_path
      assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
      assert_text "No unresolved outgoing tasks."
      assert_no_text "Monthly Migration complete"
      assert_no_horizontal_overflow
      assert_minimum_target_sizes

      click_link "Scan the Future Log"
      assert_current_path migration_future_path
      assert_text "Nothing due for #{TARGET_MONTH.strftime('%B')}."
      assert_no_text "Monthly Migration complete"
      assert_no_horizontal_overflow
      assert_minimum_target_sizes

      click_link "Finish Monthly Migration"
      assert_current_path migration_complete_path
      assert_text "Monthly Migration complete"
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  def sign_in
    sign_in_through_browser(@user)
  end

  def migration_path
    monthly_migration_path(month: month_param(TARGET_MONTH))
  end

  def migration_outgoing_path
    monthly_migration_outgoing_path(month: month_param(TARGET_MONTH))
  end

  def migration_future_path
    monthly_migration_future_path(month: month_param(TARGET_MONTH))
  end

  def migration_complete_path
    monthly_migration_complete_path(month: month_param(TARGET_MONTH))
  end

  def month_param(month)
    month.strftime("%Y-%m")
  end

  def month_context
    "#{SOURCE_MONTH.strftime('%B')} → #{TARGET_MONTH.strftime('%B %Y')}"
  end

  def target_tasks_label
    "#{TARGET_MONTH.strftime('%B')} Tasks"
  end

  def target_calendar_label
    "#{TARGET_MONTH.strftime('%B')} Calendar"
  end

  def assert_title_first
    assert_selector "main > h1:first-child", text: "Monthly Migration", count: 1
  end

  def assert_active_month_tab
    assert_selector ".tab-bar__item--active[aria-current='page']", text: "Month"
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
      ({ body: document.body.scrollWidth, viewport: document.documentElement.clientWidth })
    JAVASCRIPT
    assert_operator geometry["body"], :<=, geometry["viewport"]
  end

  def assert_minimum_target_sizes
    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("main a, main button, main input"))
        .filter((element) => {
          if (element.hidden || element.offsetParent === null) return false
          const box = element.getBoundingClientRect()
          return box.width < 44 || box.height < 44
        })
        .map((element) => element.outerHTML)
    JAVASCRIPT
    assert_empty undersized
  end

  def assert_undo_offer_consumed
    assert_no_selector ".monthly-migration__confirmation"
  end

  def assert_movement_undo(original, expected_source:, expected_kind_state: [ "task", "open" ])
    moved = original.reload.successor
    assert moved
    count_after_move = @user.entries.count

    click_button "Undo"

    assert_undo_offer_consumed
    restored = moved.reload.successor
    assert restored
    assert_equal count_after_move + 1, @user.entries.count
    assert_equal [ original.id, moved.id ], [ moved.migrated_from_id, restored.migrated_from_id ]
    assert_equal expected_kind_state, restored.values_at(:kind, :state)
    assert_equal expected_source,
      restored.values_at(:page_kind, :page_on, :collection_id, :occurs_on, :time_of_day)
    assert_equal [ original.text, original.priority, original.tags ],
      restored.values_at(:text, :priority, :tags)
    assert_uuid_v7 restored.id
    assert_selector "#entry_#{restored.id}[aria-label='Review this task']"
  end

  def set_date_field(label, date)
    field = find_field(label)
    page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
    JAVASCRIPT
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

  def create_entry(user: @user, text:, kind: "task", state: :default, page_kind:, page_on:,
    parent: nil, occurs_on: nil, time_of_day: nil, priority: false, tags: [])
    user.entries.create!(
      user: user,
      text: text,
      kind: kind,
      state: state == :default ? ("open" if kind == "task") : state,
      tags: tags,
      priority: priority,
      page_kind: page_kind,
      page_on: page_on,
      parent: parent,
      occurs_on: occurs_on,
      time_of_day: time_of_day
    )
  end
end
