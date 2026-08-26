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
end
