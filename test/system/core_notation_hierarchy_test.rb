require "application_system_test_case"

# Exercises the reader-facing notation, completion gate, and write-beneath
# gesture through the real Hotwire page at the two binding phone widths.
class CoreNotationHierarchySystemTest < ApplicationSystemTestCase
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

    capture("* ! • Protect the quiet hour")
    assert_selector ".entry__text", text: "Protect the quiet hour"
    task = @user.entries.find_by!(text: "Protect the quiet hour")
    assert_selector "#entry_#{task.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"

    reveal_actions(task)
    within("#entry_#{task.id}") do
      click_button "Edit", exact: true
      fill_in "Edit entry", with: "! Protect the quiet hour"
      click_button "Save"
    end

    assert_selector "#entry_#{task.id} .entry__signifier[aria-label='Inspiration']", text: "!"
    assert_equal [ false, true ], task.reload.values_at(:priority, :inspiration)
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

  private

  def capture(line)
    find("#capture_reveal").click
    fill_in "rapid-log-line", with: line
    click_button "Log", exact: true
  end

  def reveal_actions(entry)
    within("#entry_#{entry.id}") { find(":scope > .entry__toggle").click }
  end

  def create_task(text, **attributes)
    @user.entries.create!({
      kind: "task", state: "open", text: text, tags: [],
      page_kind: "daily", page_on: @today
    }.merge(attributes))
  end
end
