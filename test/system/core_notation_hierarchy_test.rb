require "application_system_test_case"

# Exercises the reader-facing notation, completion gate, and write-beneath
# gesture through the real Hotwire page at the two binding phone widths.
class CoreNotationHierarchySystemTest < ApplicationSystemTestCase
  STATE_PROFILES = [
    [ 390, "light", "rock-salt", "Rock Salt" ],
    [ 320, "light", "architects-daughter", "Architects Daughter" ],
    [ 390, "dark", "architects-daughter", "Architects Daughter" ],
    [ 320, "dark", "rock-salt", "Rock Salt" ]
  ].freeze
  HAND_PROFILES = [
    [ 390, "system", "marker", "light", "Permanent Marker" ],
    [ 320, "dark", "patrick-hand", nil, "Patrick Hand" ],
    [ 390, "light", "gochi-hand", nil, "Gochi Hand" ],
    [ 320, "system", "sans", "dark", "Public Sans" ]
  ].freeze

  setup do
    @user = users(:one)
    @today = Date.new(2026, 8, 28)
    travel_to Time.zone.local(2026, 8, 28, 12)
    @user.entries.update_all(deleted_at: Time.current)
    sign_in_through_browser(@user)
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
    travel_back
  end

  test "inspiration and combined signifiers capture and edit independently" do
    capture("! – Keep the recovery path simple")
    assert_selector ".entry__text", text: "Keep the recovery path simple"
    note = @user.entries.find_by!(text: "Keep the recovery path simple")
    assert_selector "#entry_#{note.id} .entry__signifier[aria-label='Inspiration']", text: "!"
    assert_selector "#entry_#{note.id} .entry__glyph", text: "–"
    assert_nil note.state
    assert_field "rapid-log-line", with: "", visible: :all
    assert_selector "#capture_reveal[aria-expanded='false']", focused: true

    capture("* ! • Protect the quiet hour")
    assert_selector ".entry__text", text: "Protect the quiet hour"
    task = @user.entries.find_by!(text: "Protect the quiet hour")
    structure = task.attributes.except("priority", "inspiration", "updated_at")
    assert_selector "#entry_#{task.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"

    reveal_actions(task)
    within("#entry_#{task.id}") do
      click_button "Edit", exact: true
      fill_in "Edit entry", with: "! Protect the quiet hour"
      click_button "Save"
    end

    assert_selector "#entry_#{task.id} .entry__signifier[aria-label='Inspiration']", text: "!"
    assert_equal [ false, true ], task.reload.values_at(:priority, :inspiration)
    assert_equal structure, task.attributes.except("priority", "inspiration", "updated_at")

    reveal_actions(task)
    within("#entry_#{task.id}") do
      click_button "Edit", exact: true
      fill_in "Edit entry", with: "* ! Protect the quiet hour"
      click_button "Save"
    end
    assert_selector "#entry_#{task.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"
    assert_equal [ true, true ], task.reload.values_at(:priority, :inspiration)
    assert_equal structure, task.attributes.except("priority", "inspiration", "updated_at")
  end

  test "add below creates a focused nested task that gates master completion" do
    master = create_task("Prepare camp")
    visit daily_log_path(date: @today.iso8601)

    reveal_actions(master)
    within("#entry_#{master.id}") do
      click_button "Add below…"
      assert_field "Add below", focused: true
      fill_in "Add below", with: "! Call the campground"
      click_button "Log", exact: true
    end

    assert_selector ".entry__text", text: "Call the campground"
    child = @user.entries.find_by!(parent: master)
    assert_selector "#entry_#{master.id} > .entry__children #entry_#{child.id}"
    assert_selector "#entry_#{child.id}.entry--selected .entry__toggle[aria-expanded='true']", focused: true
    assert_equal master.values_at(:user_id, :page_kind, :page_on, :collection_id),
      child.values_at(:user_id, :page_kind, :page_on, :collection_id)

    reveal_actions(master)
    within("#entry_#{master.id}") do
      assert_no_button "Complete"
      assert_text "Complete or strike every subtask first."
    end

    reveal_actions(child)
    within("#entry_#{child.id}") { click_button "Complete" }
    assert_selector "#entry_#{child.id} .entry__glyph", text: "x"
    reveal_actions(master)
    within("#entry_#{master.id}") do
      assert_button "Complete"
      assert_no_text "Complete or strike every subtask first."
    end
  end

  test "signifier text origins and child controls fit both binding phone profiles" do
    plain = create_task("Plain task")
    inspired = create_task("Inspired task", inspiration: true)
    both = create_task("Combined task", priority: true, inspiration: true)

    [ [ 390, "light", "rock-salt" ], [ 320, "dark", "architects-daughter" ] ].each do |width, theme, hand|
      page.current_window.resize_to(width, 844)
      page.execute_script(<<~JAVASCRIPT, theme, hand)
        document.documentElement.dataset.theme = arguments[0]
        document.documentElement.dataset.hand = arguments[1]
      JAVASCRIPT
      visit daily_log_path(date: @today.iso8601)

      origins = [ plain, inspired, both ].map do |entry|
        find("#entry_#{entry.id} .entry__text").rect.x
      end
      signifier_fit = page.evaluate_script(<<~JAVASCRIPT, "#entry_#{both.id} .entry__signifier")
        (() => {
          const element = document.querySelector(arguments[0])
          return { visible: element.clientWidth, required: element.scrollWidth }
        })()
      JAVASCRIPT
      assert_in_delta origins.first, origins.min, 0.75
      assert_in_delta origins.first, origins.max, 0.75
      assert_operator signifier_fit.fetch("required"), :<=, signifier_fit.fetch("visible")
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
        page.evaluate_script("window.innerWidth")

      reveal_actions(plain)
      within("#entry_#{plain.id}") do
        control = find_button("Add below…")
        assert_operator control.rect.height, :>=, 44
        control.click
        assert_operator find_field("Add below").rect.width, :>, 0
      end
    end
  end

  test "Morning priority gestures preserve inspiration fields and order" do
    first = create_task("Inspired first", inspiration: true)
    second = create_task("Inspired second", inspiration: true)
    original = first.attributes.except("priority", "updated_at")
    visit reflection_path

    assert_entry_order(first, second)
    reveal_actions(first)
    within("#entry_#{first.id}") { click_button "Mark priority" }
    assert_selector "#entry_#{first.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"
    assert_equal original, first.reload.attributes.except("priority", "updated_at")
    assert_entry_order(first, second)

    reveal_actions(first)
    within("#entry_#{first.id}") { click_button "Clear priority" }
    assert_selector "#entry_#{first.id} .entry__signifier[aria-label='Inspiration']", text: "!"
    assert_equal original, first.reload.attributes.except("priority", "updated_at")
    assert_entry_order(first, second)
  end

  test "nested task endpoints gate completion without cascading or reparenting" do
    master = create_task("Master")
    note = create_entry("Supporting note", kind: "note", state: nil, parent: master)
    grandchild = create_task("Grandchild", parent: note)
    visit daily_log_path(date: @today.iso8601)

    assert_selector "#entry_#{master.id} #entry_#{note.id} #entry_#{grandchild.id}"
    reveal_actions(master)
    within("#entry_#{master.id} > .entry__action-strip") do
      assert_no_button "Complete"
      assert_text "Complete or strike every subtask first."
    end
    original = snapshots(master, note, grandchild)
    submit_post(complete_entry_path(master))
    assert_text "That entry can't do that."
    assert_equal original, snapshots(master, note, grandchild)

    reveal_actions(grandchild)
    within("#entry_#{grandchild.id} > .entry__action-strip") { click_button "Strike" }
    assert_selector "#entry_#{grandchild.id} .entry__text--struck"
    reveal_actions(master)
    within("#entry_#{master.id} > .entry__action-strip") { click_button "Complete" }
    assert_selector "#entry_#{master.id} .entry__glyph", text: "x"
    assert_equal [ "done", nil, "struck" ], [ master, note, grandchild ].map { |entry| entry.reload.state }

    reveal_actions(grandchild)
    within("#entry_#{grandchild.id} > .entry__action-strip") { click_button "Reopen" }
    assert_selector "#entry_#{grandchild.id} .entry__glyph", text: "•"
    assert_equal [ "done", nil, "open" ], [ master, note, grandchild ].map { |entry| entry.reload.state }
  end

  test "a moved child endpoint keeps blocking until settled on its destination" do
    master = create_task("Master")
    child = create_task("Move me", parent: master, inspiration: true)
    visit daily_log_path(date: @today.iso8601)
    reveal_actions(child)
    within("#entry_#{child.id} > .entry__action-strip") { click_button "Migrate" }
    assert_selector "#entry_#{child.id} .entry__glyph", text: ">"
    successor = child.reload.successor

    assert_equal [ nil, "monthly_tasks", true ],
      [ successor.parent_id, successor.page_kind, successor.inspiration ]
    reveal_actions(master)
    within("#entry_#{master.id} > .entry__action-strip") do
      assert_no_button "Complete"
      assert_text "Complete or strike every subtask first."
    end

    visit monthly_log_path(month: successor.page_on.strftime("%Y-%m"), view: "tasks")
    reveal_actions(successor)
    within("#entry_#{successor.id} > .entry__action-strip") { click_button "Complete" }
    assert_selector "#entry_#{successor.id} .entry__glyph", text: "x"
    visit daily_log_path(date: @today.iso8601)
    reveal_actions(master)
    within("#entry_#{master.id} > .entry__action-strip") { click_button "Complete" }
    assert_selector "#entry_#{master.id} .entry__glyph", text: "x"
    assert_equal [ "done", "migrated", "done" ],
      [ master.reload.state, child.reload.state, successor.reload.state ]
    assert_equal master.id, child.parent_id
    assert_nil successor.parent_id
  end

  test "ordinary movement controls preserve both signifiers and predecessor history" do
    collection = Collection.create_for(user: @user, topic: "Movement Destination")
    migrate = create_task("Migrate inspired", priority: true, inspiration: true)
    calendar = create_task("Schedule calendar inspired", priority: true, inspiration: true)
    future = create_task("Schedule future inspired", priority: true, inspiration: true)
    collected = create_task("Collect inspired", priority: true, inspiration: true)

    visit source_path(migrate)
    reveal_actions(migrate)
    within("#entry_#{migrate.id} > .entry__action-strip") { click_button "Migrate" }
    assert_selector "#entry_#{migrate.id} .entry__glyph", text: ">"
    assert_movement_signifiers(migrate, expected_page: "monthly_tasks")

    visit source_path(calendar)
    schedule_through_controls(calendar, @today + 1.day)
    assert_selector "#entry_#{calendar.id} .entry__glyph", text: ">"
    assert_movement_signifiers(calendar, expected_page: "monthly_calendar")

    visit source_path(future)
    schedule_through_controls(future, @today.next_month)
    assert_selector "#entry_#{future.id} .entry__glyph", text: "<"
    assert_movement_signifiers(future, expected_page: "future")

    visit source_path(collected)
    reveal_actions(collected)
    within("#entry_#{collected.id} > .entry__action-strip") do
      click_button "Move to Collection…"
      fill_in "Exact Topic", with: collection.name
      click_button "Move", exact: true
    end
    assert_selector "#entry_#{collected.id} .entry__glyph", text: ">"
    assert_movement_signifiers(collected, expected_page: "collection")
    assert_equal collection, collected.reload.successor.collection
  end

  test "Add below writes every child kind on each writable source and repeats to arbitrary depth" do
    collection = Collection.create_for(user: @user, topic: "Hierarchy Matrix")
    sources = [
      create_task("Daily parent"),
      create_entry("Calendar parent", page_kind: "monthly_calendar", page_on: @today.beginning_of_month,
        occurs_on: @today),
      create_entry("Tasks parent", page_kind: "monthly_tasks", page_on: @today.beginning_of_month),
      create_entry("Collection parent", page_kind: "collection", page_on: nil, collection: collection)
    ]

    sources.each do |parent|
      %w[task event note].each do |kind|
        visit source_path(parent)
        reveal_actions(parent)
        within("#entry_#{parent.id} > .entry__action-strip") do
          click_button "Add below…"
          find("button[aria-label='#{kind.titleize}']").click
          fill_in "Add below", with: "#{parent.text} #{kind} child"
          click_button "Log", exact: true
        end
        assert_selector "#entry_#{parent.id} > .entry__children .entry__text",
          text: "#{parent.text} #{kind} child"
        child = @user.entries.find_by!(parent: parent, text: "#{parent.text} #{kind} child")
        assert_equal [ kind, ("open" if kind == "task"), parent.page_kind, parent.page_on, parent.collection_id ],
          child.values_at(:kind, :state, :page_kind, :page_on, :collection_id)
        assert_selector "#entry_#{parent.id} #entry_#{child.id}"
      end
    end

    nested = @user.entries.find_by!(parent: sources.first, kind: "task")
    visit source_path(nested)
    reveal_actions(nested)
    within("#entry_#{nested.id} > .entry__action-strip") do
      click_button "Add below…"
      fill_in "Add below", with: "Nested again"
      click_button "Log", exact: true
    end
    assert_selector "#entry_#{nested.id} > .entry__children .entry__text", text: "Nested again"
    deepest = @user.entries.find_by!(parent: nested, text: "Nested again")
    assert_selector "#entry_#{sources.first.id} #entry_#{nested.id} #entry_#{deepest.id}"
    assert_selector "#entry_#{deepest.id}.entry--selected .entry__toggle[aria-expanded='true']", focused: true
  end

  test "Add below stays absent and crafted requests refuse every ineligible context" do
    future_daily = create_task("Future Daily", page_on: @today.next_day)
    future_calendar = create_entry("Future Calendar", page_kind: "monthly_calendar",
      page_on: @today.next_month.beginning_of_month, occurs_on: @today.next_month)
    future_tasks = create_entry("Future Tasks", page_kind: "monthly_tasks",
      page_on: @today.next_month.beginning_of_month)
    future_log = create_entry("Future resident", page_kind: "future", page_on: nil,
      occurs_on: @today.next_month)
    done = create_task("Done", state: "done")
    struck = create_task("Struck", state: "struck")
    moved = create_task("Moved")
    moved.move_to!(page_kind: "monthly_tasks", page_on: @today.next_month.beginning_of_month, as_of: @today)
    event = create_entry("Event", kind: "event", state: nil)
    note = create_entry("Note", kind: "note", state: nil)
    hidden_root = create_task("Hidden root")
    hidden = create_task("Hidden child", parent: hidden_root)
    hidden_root.soft_delete!

    ordinary_contexts = [ future_daily, future_calendar, future_tasks, future_log, done, struck, moved, event, note ]
    ordinary_contexts.each do |entry|
      visit source_path(entry)
      assert_no_button "Add below…"
      original = snapshots(entry)
      submit_post(children_entry_path(entry), line: "Refused child", default_kind: "task")
      assert_text "That entry can't do that."
      assert_equal original, snapshots(entry)
      assert_empty @user.entries.where(parent_id: entry.id)
    end

    visit source_path(hidden)
    assert_no_selector "#entry_#{hidden.id}"
    original = snapshots(hidden_root, hidden)
    submit_post(children_entry_path(hidden), line: "Hidden child write", default_kind: "task")
    assert_text "That entry can't do that."
    assert_equal original, snapshots(hidden_root, hidden)

    lens_parent = create_task("Lens parent")
    [ [ reflection_path, "reflection_morning" ], [ evening_reflection_path, "reflection_evening" ] ].each do |path, context|
      visit path
      assert_no_button "Add below…"
      original = snapshots(lens_parent)
      submit_post(children_entry_path(lens_parent),
        line: "Lens child", default_kind: "task", return_to: context)
      assert_text "That entry can't do that."
      assert_equal original, snapshots(lens_parent)
    end

    ritual = create_task("Ritual parent", page_on: @today.prev_month)
    target_month = @today.beginning_of_month.strftime("%Y-%m")
    visit monthly_migration_outgoing_path(month: target_month)
    assert_no_button "Add below…"
    original = snapshots(ritual)
    submit_post(children_entry_path(ritual),
      line: "Ritual child", default_kind: "task", month: target_month)
    assert_text "That entry can't do that."
    assert_equal original, snapshots(ritual)

    unavailable = Collection.create_for(user: @user, topic: "Unavailable")
    unavailable_parent = create_entry("Unavailable parent", page_kind: "collection", page_on: nil,
      collection: unavailable)
    unavailable.update_columns(deleted_at: Time.current)
    visit collection_path(unavailable)
    assert_text "Collection not found"
    assert_no_button "Add below…"
    original = snapshots(unavailable_parent)
    submit_post(children_entry_path(unavailable_parent), line: "No child", default_kind: "task")
    assert_text "Collection not found"
    assert_equal original, snapshots(unavailable_parent)
  end

  test "browser-session adversarial commands stay nondisclosing and snapshot preserving" do
    foreign = create_entry("Foreign secret", user: users(:two))
    tombstone = create_task("Deleted secret")
    tombstone.soft_delete!
    missing_id = SecureRandom.uuid
    visit daily_log_path(date: @today.iso8601)
    original_secrets = snapshots(foreign, tombstone)
    original_count = Entry.count

    responses = [ missing_id, foreign.id, tombstone.id ].map do |id|
      browser_post(children_entry_path(id), line: "Probe", default_kind: "task")
    end
    assert_equal [ 404, 404, 404 ], responses.map { |response| response.fetch("status") }
    assert_equal 1, responses.map { |response| response.fetch("body") }.uniq.size
    assert_equal original_count, Entry.count
    assert_equal original_secrets, snapshots(foreign, tombstone)

    valid = create_task("Claims target")
    original = snapshots(valid)
    claims = {
      line: "Claimed child", default_kind: "task", user_id: users(:two).id,
      page_kind: "future", page_on: @today.next_day.iso8601,
      collection_id: collections(:camping).id, parent_id: foreign.id,
      migrated_from_id: foreign.id, state: "done", deleted_at: Time.current.iso8601,
      created_at: 1.day.ago.iso8601, updated_at: 1.day.ago.iso8601,
      hlc: "claimed", server_seq: 99
    }
    response = browser_post(children_entry_path(valid), **claims)
    assert_equal 200, response.fetch("status")
    assert_includes response.fetch("body"), "That entry can&#39;t do that."
    assert_equal original, snapshots(valid)
    assert_empty @user.entries.where(parent_id: valid.id)

    master = create_task("Malformed master")
    cyclic = create_task("Malformed cycle", parent: master)
    cyclic.update_columns(migrated_from_id: cyclic.id, state: "migrated")
    original = snapshots(master, cyclic)
    visit source_path(master)
    submit_post(complete_entry_path(master))
    assert_text "That entry can't do that."
    assert_equal original, snapshots(master, cyclic)

    stale_master = create_task("Stale master")
    stale_child = create_task("Stale child", state: "done", parent: stale_master)
    visit source_path(stale_master)
    reveal_actions(stale_master)
    within("#entry_#{stale_master.id} > .entry__action-strip") { assert_button "Complete" }
    stale_child.reopen!
    original = snapshots(stale_master, stale_child)
    submit_post(complete_entry_path(stale_master))
    assert_text "That entry can't do that."
    assert_equal original, snapshots(stale_master, stale_child)
  end

  test "every core rendered state passes all four phone profiles" do
    plain = create_task("Plain origin")
    inspired = create_task("Inspired origin", inspiration: true)
    combined = create_task("Combined origin", priority: true, inspiration: true)
    blocked = create_task("Blocked master")
    create_task("Open blocker", parent: blocked)
    ready = create_task("Ready master")
    create_task("Settled child", state: "done", parent: ready)
    add_parent = create_task("Add-below parent")
    stale_master = create_task("Stale master")
    stale_child = create_task("Stale settled child", state: "done", parent: stale_master)
    deep = create_task("A long combined-signifier master whose words wrap safely " * 3,
      priority: true, inspiration: true, tags: %w[long metadata])
    5.times do |depth|
      deep = create_entry("Deep wrapping context #{depth} " * 5,
        kind: "note", state: nil, parent: deep, priority: depth.even?, inspiration: depth.odd?)
    end
    unavailable = Collection.create_for(user: @user, topic: "Profile unavailable")
    create_entry("Unavailable collection state", page_kind: "collection", page_on: nil,
      collection: unavailable)
    unavailable.update_columns(deleted_at: Time.current)

    STATE_PROFILES.each do |width, theme, hand, hand_face|
      stale_child.update_columns(state: "done")
      visit daily_log_path(date: @today.iso8601)
      set_profile(width:, theme:, hand:)
      visit daily_log_path(date: @today.iso8601)

      assert_selector "html[data-theme='#{theme}'][data-hand='#{hand}']", visible: :all
      assert_stable_origins(plain, inspired, combined)
      reveal_actions(blocked)
      within("#entry_#{blocked.id} > .entry__action-strip") do
        assert_no_button "Complete"
        assert_text "Complete or strike every subtask first."
      end
      reveal_actions(ready)
      within("#entry_#{ready.id} > .entry__action-strip") do
        assert_button "Complete"
        assert_no_text "Complete or strike every subtask first."
      end
      reveal_actions(add_parent)
      within("#entry_#{add_parent.id} > .entry__action-strip") do
        click_button "Add below…"
        assert_field "Add below", focused: true
        assert_selector "button[aria-label='Task'][aria-pressed='true']"
      end
      assert_selector "#entry_#{add_parent.id} > .entry__toggle[aria-expanded='true']"
      assert_core_phone_geometry(hand_face:, deep_entry: deep)

      fill_in "Add below", with: "!"
      click_button "Log", exact: true
      assert_text "That entry can't do that."
      assert_field "Add below", with: "!", focused: true
      assert_selector "#entry_#{add_parent.id} > .entry__toggle[aria-expanded='true']"
      assert_core_phone_geometry(hand_face:, deep_entry: deep)

      visit daily_log_path(date: @today.iso8601)
      reveal_actions(stale_master)
      within("#entry_#{stale_master.id} > .entry__action-strip") { assert_button "Complete" }
      stale_child.reopen!
      submit_post(complete_entry_path(stale_master))
      assert_text "That entry can't do that."
      assert_equal %w[open open], [ stale_master.reload.state, stale_child.reload.state ]
      assert_core_phone_geometry(hand_face:, deep_entry: deep)

      visit collection_path(unavailable)
      assert_text "Collection not found"
      assert_no_horizontal_overflow
      assert_visible_text_uses(hand_face, ".collection-page h1")
    end
  end

  test "representative deep Add-below state covers remaining hands and system themes" do
    root = create_task("Representative long inspired hierarchy " * 4,
      priority: true, inspiration: true, tags: %w[representative metadata])
    child = create_task("Nested task with another long line " * 4, parent: root,
      priority: true, inspiration: true)

    HAND_PROFILES.each do |width, theme, hand, os_theme, hand_face|
      emulate_color_scheme(os_theme || "light")
      visit daily_log_path(date: @today.iso8601)
      set_profile(width:, theme:, hand:)
      visit daily_log_path(date: @today.iso8601)
      reveal_actions(child)
      within("#entry_#{child.id} > .entry__action-strip") { click_button "Add below…" }

      if theme == "system"
        assert_no_selector "html[data-theme]", visible: :all
        expected_background = os_theme == "dark" ? "rgb(22, 22, 30)" : "rgb(246, 241, 230)"
        assert_equal expected_background, page.evaluate_script("getComputedStyle(document.documentElement).backgroundColor")
      else
        assert_selector "html[data-theme='#{theme}']", visible: :all
      end
      if hand == "marker"
        assert_no_selector "html[data-hand]", visible: :all
      else
        assert_selector "html[data-hand='#{hand}']", visible: :all
      end
      assert_field "Add below", focused: true
      assert_core_phone_geometry(hand_face:, deep_entry: child)
    end
  ensure
    emulate_color_scheme("light")
  end

  private

  def capture(line)
    find("#capture_reveal").click
    fill_in "rapid-log-line", with: line
    click_button "Log", exact: true
  end

  def reveal_actions(entry)
    find("#entry_#{entry.id} > .entry__toggle").click
  end

  def create_task(text, **attributes)
    create_entry(text, **attributes)
  end

  def create_entry(text, **attributes)
    owner = attributes.delete(:user) || @user
    owner.entries.create!({
      kind: "task", state: "open", text: text, tags: [], priority: false, inspiration: false,
      page_kind: "daily", page_on: @today
    }.merge(attributes))
  end

  def source_path(entry)
    case entry.page_kind
    when "daily"
      daily_log_path(date: entry.page_on.iso8601)
    when "monthly_calendar"
      monthly_log_path(month: entry.page_on.strftime("%Y-%m"))
    when "monthly_tasks"
      monthly_log_path(month: entry.page_on.strftime("%Y-%m"), view: "tasks")
    when "collection"
      collection_path(entry.collection)
    when "future"
      future_log_path
    end
  end

  def schedule_through_controls(entry, date)
    reveal_actions(entry)
    within("#entry_#{entry.id} > .entry__action-strip") do
      click_button "Schedule…"
      field = find_field("Schedule for")
      page.execute_script(<<~JAVASCRIPT, field, date.iso8601)
        arguments[0].value = arguments[1]
        arguments[0].dispatchEvent(new Event("input", { bubbles: true }))
        arguments[0].dispatchEvent(new Event("change", { bubbles: true }))
      JAVASCRIPT
      click_button "Schedule", exact: true
    end
  end

  def assert_movement_signifiers(predecessor, expected_page:)
    successor = predecessor.reload.successor
    assert_equal [ expected_page, true, true ],
      successor.values_at(:page_kind, :priority, :inspiration)
    assert_equal [ true, true ], predecessor.values_at(:priority, :inspiration)
    assert_selector "#entry_#{predecessor.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"
  end

  def assert_entry_order(first, second)
    positions = [ first, second ].map { |entry| page.html.index("entry_#{entry.id}") }
    assert_equal positions.sort, positions
  end

  def set_profile(width:, theme:, hand:)
    page.current_window.resize_to(width, 844)
    cycle_profile_until("theme", theme == "system" ? nil : theme, /Theme:/)
    cycle_profile_until("hand", hand == "marker" ? nil : hand, /Hand:/)
  end

  def cycle_profile_until(attribute, target, label)
    until current_profile_value(attribute) == target
      button = find("button", text: label)
      previous_label = button.text
      button.click
      assert_no_button previous_label, exact: true
    end
  end

  def current_profile_value(attribute)
    page.find("html", visible: :all)["data-#{attribute}"]
  end

  def assert_stable_origins(*entries)
    origins = entries.map { |entry| find("#entry_#{entry.id} .entry__text").rect.x }
    assert_in_delta origins.first, origins.min, 0.75
    assert_in_delta origins.first, origins.max, 0.75
  end

  def assert_core_phone_geometry(hand_face:, deep_entry:)
    assert_no_horizontal_overflow
    assert_no_clipped_core_elements
    assert_minimum_targets
    assert_visible_core_text_uses(hand_face)
    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
    clearance = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const entry = document.querySelector("#entry_#{deep_entry.id}").getBoundingClientRect()
        const tabs = document.querySelector(".tab-bar").getBoundingClientRect()
        return { entryBottom: entry.bottom, tabsTop: tabs.top }
      })()
    JAVASCRIPT
    assert_operator clearance.fetch("entryBottom"), :<=, clearance.fetch("tabsTop")
  end

  def assert_no_horizontal_overflow
    geometry = page.evaluate_script(<<~JAVASCRIPT)
      ({ page: document.documentElement.scrollWidth, viewport: document.documentElement.clientWidth })
    JAVASCRIPT
    assert_operator geometry.fetch("page"), :<=, geometry.fetch("viewport")
  end

  def assert_no_clipped_core_elements
    clipped = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const selectors = [
          ".entry__signifier", ".entry__glyph", ".entry__text", ".entry__meta",
          ".entry__children", ".entry__completion-blocked", ".entry__action-strip",
          ".entry__child", ".entry__edit"
        ]
        return Array.from(document.querySelectorAll(selectors.join(",")))
          .filter((element) => element.offsetParent !== null)
          .filter((element) => {
            const box = element.getBoundingClientRect()
            return box.left < -0.5 || box.right > document.documentElement.clientWidth + 0.5 ||
              element.scrollWidth > element.clientWidth + 1
          })
          .map((element) => `${element.className}: ${element.getBoundingClientRect().left}-${element.getBoundingClientRect().right}`)
      })()
    JAVASCRIPT
    assert_empty clipped
  end

  def assert_minimum_targets
    undersized = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("main a, main button, main input"))
        .filter((element) => element.offsetParent !== null)
        .filter((element) => {
          const box = element.getBoundingClientRect()
          return box.width < 44 || box.height < 44
        })
        .map((element) => element.outerHTML)
    JAVASCRIPT
    assert_empty undersized
  end

  def assert_visible_core_text_uses(hand_face)
    selectors = [
      "main h1", ".entry__text", ".entry__meta", ".entry__completion-blocked",
      ".entry__action-strip button", ".field-label", ".daily-log__preferences button", ".tab-bar a"
    ]
    selectors.each { |selector| assert_visible_text_uses(hand_face, selector) }
  end

  def assert_visible_text_uses(hand_face, selector)
    fonts = page.evaluate_script(<<~JAVASCRIPT, selector)
      Array.from(document.querySelectorAll(arguments[0]))
        .filter((element) => element.offsetParent !== null)
        .map((element) => getComputedStyle(element).fontFamily)
    JAVASCRIPT
    return if fonts.empty?

    fonts.each { |font| assert_includes font, hand_face }
  end

  def emulate_color_scheme(theme)
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-color-scheme", value: theme } ]
    )
  end

  def snapshots(*entries)
    entries.map { |entry| entry.reload.attributes }
  end

  def submit_post(path, params = {})
    page.execute_script(<<~JAVASCRIPT, path, params)
      const form = document.createElement("form")
      form.method = "post"
      form.action = arguments[0]
      Object.entries(arguments[1]).forEach(([name, value]) => {
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

  def browser_post(path, **params)
    page.evaluate_async_script(<<~JAVASCRIPT, path, params)
      const path = arguments[0]
      const params = arguments[1]
      const done = arguments[2]
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const body = new URLSearchParams(params)
      if (token) body.set("authenticity_token", token)
      fetch(path, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" },
        body: body.toString()
      }).then(async (response) => {
        done({ status: response.status, body: await response.text() })
      }).catch((error) => done({ status: 0, body: error.toString() }))
    JAVASCRIPT
  end
end
