require "application_system_test_case"
require "digest"
require "json"

# Replays every immutable geometry row against the T2 bundle and the exact T0
# stylesheet on the same live DOM. Comparing one state twice isolates migration
# drift from fixture text, timestamps, font rendering, and browser build noise.
class TailwindGeometryParityTest < ApplicationSystemTestCase
  T0_STYLESHEET_PATH = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  T0_STYLESHEET_BYTES = 23_218
  T0_STYLESHEET_SHA256 = "df75385665a9f4f48af1f66156953e712493c2e85575de861ffc09963bfa5ceb"
  GEOMETRY_CONTRACT = JSON.parse(
    Rails.root.join("docs/tailwind-v4-baseline/geometry.json").read
  ).freeze
  PROFILES = {
    "390-light-rock-salt" => { width: 390, theme: "light", hand: "rock-salt" },
    "320-dark-architects" => { width: 320, theme: "dark", hand: "architects-daughter" },
    "390-system-marker" => { width: 390, theme: nil, hand: nil }
  }.freeze
  METRIC_SELECTORS = {
    "alert" => "[role='alert']",
    "calendarDailyLink" => ".monthly-calendar__daily-link",
    "calendarDay" => ".monthly-calendar__day",
    "calendarResidents" => ".monthly-calendar__residents",
    "calendarReveal" => ".monthly-calendar__capture-reveal",
    "dateInput" => "input[type='date']",
    "entryGlyph" => ".entry__glyph",
    "entryLine" => ".entry__line",
    "entryMeta" => ".entry__meta",
    "entrySignifier" => ".entry__signifier",
    "entryText" => ".entry__text",
    "flash" => ".flash",
    "notice" => ".flash--notice",
    "page" => "body",
    "rapidLog" => ".rapid-log",
    "tabs" => ".tab-bar",
    "title" => "h1",
    "trailingDaily" => ".daily-log__capture-reveal",
    "trailingMonthlyTasks" => "[data-page-capture='monthly_tasks'] .daily-log__capture-reveal"
  }.freeze
  STYLE_PROPERTIES = %w[display fontFamily fontSize gridTemplateColumns].freeze
  NUMERIC_PROPERTIES = %w[x y right bottom width height].freeze
  POST_T0_CALENDAR_VERTICAL_METRICS = %w[
    calendarDailyLink calendarDay calendarResidents calendarReveal
    entryGlyph entryLine entryMeta entrySignifier entryText
  ].freeze
  POST_T0_CALENDAR_SIZED_METRICS = %w[calendarDay calendarResidents entryLine].freeze
  FRACTIONAL_PIXEL_TOLERANCE = 0.75

  setup do
    @user = users(:one)
    @today = Date.new(2026, 8, 27)
    travel_to Time.zone.local(2026, 8, 27, 12)
    reset_journal
    sign_in_through_browser(@user)
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
    travel_back
  end

  test "all 102 recorded geometry rows retain T0 except the approved Calendar baseline correction" do
    assert_equal 102, GEOMETRY_CONTRACT.size
    assert_equal({
      "390-light-rock-salt" => 34,
      "320-dark-architects" => 34,
      "390-system-marker" => 34
    }, GEOMETRY_CONTRACT.map { |row| row.fetch("profile") }.tally)
    assert_equal T0_STYLESHEET_BYTES, t0_stylesheet.bytesize
    assert_equal T0_STYLESHEET_SHA256, Digest::SHA256.hexdigest(t0_stylesheet)

    verified = GEOMETRY_CONTRACT.count do |contract|
      reset_journal
      render_geometry_state(contract.fetch("state"))
      apply_profile(contract.fetch("profile"))
      wait_for_render
      align_to_recorded_scroll(contract)

      scroll_y = page.evaluate_script("window.scrollY")
      current = sample_geometry(contract)
      baseline = sample_with_t0_stylesheet(contract, scroll_y: scroll_y)
      assert_contract_shape(contract, current)
      assert_contract_styles(contract, current)
      assert_stable_recorded_anchors(contract, current)
      assert_same_geometry(contract, baseline, current)
      true
    end

    assert_equal 102, verified
  end

  private

  def t0_stylesheet
    @t0_stylesheet ||= T0_STYLESHEET_PATH.binread
  end

  def reset_journal
    Entry.where(user_id: @user.id).delete_all
    Collection.where(user_id: @user.id).delete_all
  end

  def render_geometry_state(state)
    send("render_#{state.tr('-', '_')}")
  end

  def render_daily_empty
    visit root_path
  end

  def render_daily_populated_long
    create_daily_entries
    visit root_path
  end

  def render_daily_schedule_empty
    task = create_daily_entries
    visit root_path
    reveal_schedule(task)
  end

  def render_daily_schedule_selected
    task = create_daily_entries
    visit root_path
    reveal_schedule(task)
    set_date_field("Schedule for", @today.next_month + 19.days)
  end

  def render_daily_refusal
    task = create_daily_entries
    visit root_path
    reveal_entry(task)
    task.complete!
    within("#entry_#{task.id}") { click_button "Complete", exact: true }
  end

  def render_monthly_tasks_empty
    visit monthly_tasks_path
  end

  def render_monthly_tasks_populated
    create_monthly_task_entries
    visit monthly_tasks_path
  end

  def render_monthly_tasks_capture
    create_monthly_task_entries
    visit monthly_tasks_path
    find("#monthly_tasks_capture_reveal").click
  end

  def render_monthly_calendar_populated
    create_calendar_entries(on: @today)
    visit monthly_calendar_path
  end

  def render_monthly_calendar_residents
    target_day = @today.beginning_of_month + 6.days
    create_calendar_entries(on: target_day, complete_set: true)
    visit monthly_calendar_path
    first(".monthly-calendar__day[data-date='#{target_day.iso8601}'] .entry").scroll_to(:center)
  end

  def render_monthly_calendar_capture
    create_calendar_entries(on: @today)
    visit monthly_calendar_path
    first(".monthly-calendar__capture-reveal").click
  end

  def render_future_empty
    visit future_log_path
  end

  def render_future_populated
    create_future_entry
    visit future_log_path
  end

  def render_future_capture
    create_future_entry
    visit future_log_path
    find("#future_month_#{target_month.strftime('%Y_%m')}_toggle").click
  end

  def render_index_empty
    visit journal_index_path
  end

  def render_index_populated_long
    collection = create_collection("This Is An Intentionally Very Long Indexed Collection Topic Used To Preserve Wrapping Geometry")
    create_collection_entry(collection)
    collection.register!
    visit journal_index_path
  end

  def render_index_refusal
    visit journal_index_path
    find("#new_collection_toggle").click
    click_button "Create", exact: true
  end

  def render_collection_empty_unindexed
    collection = create_collection("Camping Master Collection")
    visit collection_path(collection)
  end

  def render_collection_populated_indexed
    collection = create_collection("Camping Master Collection")
    create_collection_entry(collection)
    collection.register!
    visit collection_path(collection)
  end

  def render_collection_missing
    visit collection_path("missing-collection")
  end

  def render_migration_setup_empty
    visit migration_path
  end

  def render_migration_outgoing
    create_outgoing_task
    visit migration_outgoing_path
  end

  def render_migration_outgoing_collection_step
    create_outgoing_task
    visit migration_outgoing_path
    click_button "Collection…", exact: true
  end

  def render_migration_outgoing_future_step
    create_outgoing_task
    visit migration_outgoing_path
    click_button "Future…", exact: true
  end

  def render_migration_refusal
    create_outgoing_task
    visit migration_outgoing_path
    click_button "Collection…", exact: true
    fill_in "Exact Topic", with: "No Such Topic"
    click_button "Move", exact: true
  end

  def render_migration_outgoing_checkpoint
    visit migration_outgoing_path
  end

  def render_migration_future_task
    create_due_future_entry
    visit migration_future_path
  end

  def render_migration_future_event
    create_due_future_entry(kind: "event")
    visit migration_future_path
  end

  def render_migration_undo
    create_due_future_entry(kind: "event")
    visit migration_future_path
    click_button target_calendar_label, exact: true
  end

  def render_migration_future_checkpoint
    visit migration_future_path
  end

  def render_migration_complete
    visit migration_future_path
    click_link "Finish Monthly Migration", exact: true
  end

  def render_migration_stale_refusal
    create_outgoing_task(text: "Already resolved ritual candidate")
    create_outgoing_task(text: "Stale ritual candidate")
    stale = @user.entries.monthly_calendar(source_month).first
    visit migration_outgoing_path
    stale.strike!
    click_button "Strike", exact: true
  end

  def render_migration_item_missing
    visit migration_path
    submit_post(strike_monthly_migration_outgoing_path(month: target_month_param, id: "missing-entry"))
  end

  def render_migration_not_found
    visit monthly_migration_path(month: @today.strftime("%Y-%m"))
  end

  def create_daily_entries
    task = create_entry(
      text: "A deliberately long daily task heading that wraps across a narrow phone without squeezing its metadata out of view",
      page_kind: "daily", page_on: @today, priority: true, tags: %w[home long daily]
    )
    create_entry(
      text: "Call the campground", kind: "event", state: nil,
      page_kind: "daily", page_on: @today, occurs_on: @today, time_of_day: "18:00"
    )
    create_entry(
      text: "Remember the quiet details", kind: "note", state: nil,
      page_kind: "daily", page_on: @today
    )
    task
  end

  def create_monthly_task_entries
    create_entry(
      text: "A long monthly task that establishes the shared signifier bullet text and metadata columns",
      page_kind: "monthly_tasks", page_on: @today.beginning_of_month,
      priority: true, tags: %w[month baseline]
    )
    finished = create_entry(text: "Finished monthly task", page_kind: "monthly_tasks", page_on: @today.beginning_of_month)
    finished.complete!
    struck = create_entry(text: "Struck monthly task", page_kind: "monthly_tasks", page_on: @today.beginning_of_month)
    struck.strike!
    create_entry(
      text: "Monthly event", kind: "event", state: nil,
      page_kind: "monthly_tasks", page_on: @today.beginning_of_month
    )
    create_entry(
      text: "Monthly note", kind: "note", state: nil,
      page_kind: "monthly_tasks", page_on: @today.beginning_of_month
    )
  end

  def create_calendar_entries(on:, complete_set: false)
    create_entry(text: "Calendar task", page_kind: "monthly_calendar", page_on: on.beginning_of_month, occurs_on: on)
    return unless complete_set

    create_entry(
      text: "Calendar event", kind: "event", state: nil,
      page_kind: "monthly_calendar", page_on: on.beginning_of_month,
      occurs_on: on, time_of_day: "18:20"
    )
    create_entry(
      text: "A long calendar note that wraps while day number weekday text and metadata stay aligned",
      kind: "note", state: nil, page_kind: "monthly_calendar",
      page_on: on.beginning_of_month, occurs_on: on, tags: %w[long calendar]
    )
  end

  def create_future_entry
    create_entry(
      text: "A future task that wraps while its day bullet text time tags and movement metadata retain one readable grid",
      page_kind: "future", page_on: nil, occurs_on: target_month + 5.days,
      time_of_day: "09:30", priority: true, tags: %w[future]
    )
  end

  def create_collection(name)
    @user.collections.create!(name: name)
  end

  def create_collection_entry(collection)
    create_entry(
      text: "A collection baseline task with enough words to prove the Topic and resident columns wrap on a narrow screen",
      page_kind: "collection", page_on: nil, collection: collection,
      priority: true, tags: %w[collection baseline]
    )
  end

  def create_outgoing_task(text: "Calendar task")
    create_entry(
      text: text, page_kind: "monthly_calendar",
      page_on: source_month, occurs_on: source_month + 5.days
    )
  end

  def create_due_future_entry(kind: "task")
    create_entry(
      text: kind == "task" ? "Future task" : "Campground opens",
      kind: kind, state: ("open" if kind == "task"), page_kind: "future",
      page_on: nil, occurs_on: target_month + (kind == "task" ? 3.days : 6.days),
      time_of_day: ("09:00" if kind == "event")
    )
  end

  def create_entry(text:, page_kind:, page_on:, kind: "task", state: "open",
    occurs_on: nil, time_of_day: nil, priority: false, tags: [], collection: nil)
    @user.entries.create!(
      text: text, kind: kind, state: state, tags: tags, priority: priority,
      page_kind: page_kind, page_on: page_on, occurs_on: occurs_on,
      time_of_day: time_of_day, collection: collection
    )
  end

  def reveal_entry(entry)
    within("#entry_#{entry.id}") { find(".entry__toggle").click }
  end

  def reveal_schedule(entry)
    reveal_entry(entry)
    within("#entry_#{entry.id}") { click_button "Schedule…", exact: true }
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
    page.execute_script(<<~JAVASCRIPT, path)
      const form = document.createElement("form")
      form.method = "post"
      form.action = arguments[0]
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

  def apply_profile(profile_name)
    profile = PROFILES.fetch(profile_name)
    page.current_window.resize_to(profile.fetch(:width), 844)
    chrome = page.evaluate_script(<<~JAVASCRIPT)
      ({ width: window.outerWidth - window.innerWidth,
         height: window.outerHeight - window.innerHeight })
    JAVASCRIPT
    page.current_window.resize_to(
      profile.fetch(:width),
      844 + chrome.fetch("height")
    )
    page.execute_script(<<~JAVASCRIPT, profile[:theme], profile[:hand])
      const browserProfile = document.createElement("style")
      browserProfile.textContent = "html { scrollbar-width: none } ::-webkit-scrollbar { width: 0 }"
      document.head.appendChild(browserProfile)
      if (arguments[0]) document.documentElement.dataset.theme = arguments[0]
      else delete document.documentElement.dataset.theme
      if (arguments[1]) document.documentElement.dataset.hand = arguments[1]
      else delete document.documentElement.dataset.hand
    JAVASCRIPT
  end

  def wait_for_render
    page.driver.browser.execute_async_script(<<~JAVASCRIPT)
      const done = arguments[arguments.length - 1]
      document.fonts.ready.then(() => requestAnimationFrame(() => requestAnimationFrame(done)))
    JAVASCRIPT
  end

  def align_to_recorded_scroll(contract)
    expected_title_y = contract.dig("title", "y")
    page.execute_script(<<~JAVASCRIPT, expected_title_y)
      const title = document.querySelector("h1")
      const documentY = title.getBoundingClientRect().y + window.scrollY
      window.scrollTo(0, Math.max(0, documentY - arguments[0]))
    JAVASCRIPT
    wait_for_render
  end

  def sample_with_t0_stylesheet(contract, scroll_y:)
    page.execute_script(<<~JAVASCRIPT, t0_stylesheet)
      const link = document.querySelector("link[rel='stylesheet'][href*='/assets/tailwind']")
      link.disabled = true
      const style = document.createElement("style")
      style.id = "t0-geometry-stylesheet"
      style.textContent = arguments[0]
      document.head.appendChild(style)
    JAVASCRIPT
    wait_for_render
    page.execute_script("window.scrollTo(0, arguments[0])", scroll_y)
    wait_for_render
    sample_geometry(contract)
  ensure
    page.execute_script(<<~JAVASCRIPT)
      document.querySelector("#t0-geometry-stylesheet")?.remove()
      const link = document.querySelector("link[rel='stylesheet'][href*='/assets/tailwind']")
      if (link) link.disabled = false
    JAVASCRIPT
    wait_for_render
  end

  def sample_geometry(contract)
    selectors = METRIC_SELECTORS.select { |key, _selector| contract[key] }
    page.evaluate_script(<<~JAVASCRIPT, selectors.to_json)
      (() => {
        const selectors = JSON.parse(arguments[0])
        const metric = (selector) => {
          const element = document.querySelector(selector)
          if (!element) return null
          const rectangle = element.getBoundingClientRect()
          const style = getComputedStyle(element)
          return {
            x: rectangle.x, y: rectangle.y, right: rectangle.right,
            bottom: rectangle.bottom, width: rectangle.width, height: rectangle.height,
            display: style.display, fontFamily: style.fontFamily,
            fontSize: style.fontSize, gridTemplateColumns: style.gridTemplateColumns
          }
        }
        const result = Object.fromEntries(
          Object.entries(selectors).map(([name, selector]) => [name, metric(selector)])
        )
        result.viewport = {
          width: window.innerWidth,
          height: window.innerHeight,
          scrollWidth: document.documentElement.scrollWidth,
          scrollHeight: document.documentElement.scrollHeight
        }
        return result
      })()
    JAVASCRIPT
  end

  def assert_contract_shape(contract, current)
    METRIC_SELECTORS.each_key do |key|
      next unless contract[key]

      assert current[key], "#{row_label(contract)} did not render #{key}"
    end
  end

  def assert_contract_styles(contract, current)
    METRIC_SELECTORS.each_key do |key|
      next unless contract[key]

      STYLE_PROPERTIES.first(3).each do |property|
        assert_equal contract.dig(key, property), current.dig(key, property),
          "#{row_label(contract)} #{key}.#{property} left its recorded contract"
      end
    end
  end

  def assert_stable_recorded_anchors(contract, current)
    %w[width height scrollWidth].each do |property|
      assert_in_delta contract.dig("viewport", property), current.dig("viewport", property),
        FRACTIONAL_PIXEL_TOLERANCE, "#{row_label(contract)} viewport.#{property} drifted"
    end
    %w[x width right].each do |property|
      assert_in_delta contract.dig("page", property), current.dig("page", property),
        FRACTIONAL_PIXEL_TOLERANCE, "#{row_label(contract)} page.#{property} drifted"
    end
    if contract["tabs"]
      NUMERIC_PROPERTIES.each do |property|
        assert_in_delta contract.dig("tabs", property), current.dig("tabs", property),
          FRACTIONAL_PIXEL_TOLERANCE, "#{row_label(contract)} tabs.#{property} drifted"
      end
    end
    title_properties = [ "x" ]
    title_properties << "y" if contract.dig("title", "y") >= 0
    title_properties.each do |property|
      assert_in_delta contract.dig("title", property), current.dig("title", property),
        FRACTIONAL_PIXEL_TOLERANCE, "#{row_label(contract)} title.#{property} drifted"
    end
  end

  def assert_same_geometry(contract, baseline, current)
    current.each do |key, metric|
      baseline_metric = baseline.fetch(key)
      if key == "viewport"
        metric.each do |property, value|
          next if post_t0_calendar_exception?(contract, key, property)

          assert_in_delta value, baseline_metric.fetch(property), FRACTIONAL_PIXEL_TOLERANCE,
            "#{row_label(contract)} viewport.#{property} changed from T0"
        end
        next
      end

      NUMERIC_PROPERTIES.each do |property|
        next if post_t0_calendar_exception?(contract, key, property)

        assert_in_delta metric.fetch(property), baseline_metric.fetch(property),
          FRACTIONAL_PIXEL_TOLERANCE, "#{row_label(contract)} #{key}.#{property} changed from T0"
      end
      STYLE_PROPERTIES.each do |property|
        assert_equal metric.fetch(property), baseline_metric.fetch(property),
          "#{row_label(contract)} #{key}.#{property} changed from T0"
      end
    end
  end

  def post_t0_calendar_exception?(contract, metric, property)
    return false unless contract.fetch("state").start_with?("monthly-calendar-")
    return true if metric == "viewport" && property == "scrollHeight"
    return true if metric == "page" && %w[bottom height].include?(property)
    return false unless POST_T0_CALENDAR_VERTICAL_METRICS.include?(metric)
    return true if %w[y bottom].include?(property)

    property == "height" && POST_T0_CALENDAR_SIZED_METRICS.include?(metric)
  end

  def row_label(contract)
    "#{contract.fetch('profile')}/#{contract.fetch('state')}"
  end

  def monthly_tasks_path
    monthly_log_path(month: @today.strftime("%Y-%m"), view: "tasks")
  end

  def monthly_calendar_path
    monthly_log_path(month: @today.strftime("%Y-%m"))
  end

  def target_month
    @today.next_month.beginning_of_month
  end

  def source_month
    target_month.prev_month
  end

  def target_month_param
    target_month.strftime("%Y-%m")
  end

  def migration_path
    monthly_migration_path(month: target_month_param)
  end

  def migration_outgoing_path
    monthly_migration_outgoing_path(month: target_month_param)
  end

  def migration_future_path
    monthly_migration_future_path(month: target_month_param)
  end

  def target_calendar_label
    "#{target_month.strftime('%B')} Calendar"
  end
end
