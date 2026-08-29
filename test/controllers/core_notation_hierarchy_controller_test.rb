require "test_helper"

class CoreNotationHierarchyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @today = Time.zone.today
  end

  test "blocked master omits Complete and shows the exact helper" do
    master = create_open_task("Master", page_on: @today)
    create_open_task("Open child", page_on: @today, parent: master)

    get daily_log_path(date: @today.iso8601)

    assert_response :success
    assert_select "#entry_#{master.id} form[action='#{complete_entry_path(master)}']", count: 0
    assert_select "#entry_#{master.id} .entry__completion-blocked",
      text: "Complete or strike every subtask first."
  end

  test "add below creates a child from the persisted parent and returns canonically" do
    parent = create_open_task("Parent", page_on: @today)

    assert_difference -> { @user.entries.count }, 1 do
      post children_entry_path(parent), params: {
        line: "! – Supporting note", default_kind: "task"
      }
    end

    child = @user.entries.find_by!(parent: parent)
    assert_equal [ "note", nil, true, "daily", @today ],
      child.values_at(:kind, :state, :inspiration, :page_kind, :page_on)
    assert_redirected_to daily_log_path(date: @today.iso8601)
    assert_nil flash[:child_parent_id]
    assert_equal child.id, flash[:child_focus_id]
  end

  test "add below refuses forbidden claims and retains the submitted form" do
    parent = create_open_task("Parent", page_on: @today)
    original = parent.attributes

    assert_no_difference -> { Entry.count } do
      post children_entry_path(parent), params: {
        line: "crafted child", default_kind: "event", parent_id: entries(:open_task).id,
        page_kind: "future", user_id: users(:two).id, hlc: "crafted", unknown: "claim"
      }
    end

    assert_equal original, parent.reload.attributes
    assert_redirected_to daily_log_path(date: @today.iso8601)
    assert_equal "That entry can't do that.", flash[:alert]
    assert_equal parent.id, flash[:child_parent_id]
    assert_equal "crafted child", flash[:child_line]
    assert_equal "event", flash[:child_kind]
  end

  test "future foreign deleted and settled parents cannot receive children" do
    future = @user.entries.create!(kind: "task", state: "open", text: "Future", tags: [],
      page_kind: "future", page_on: nil, occurs_on: @today.next_month)
    done = create_open_task("Done", page_on: @today).tap(&:complete!)
    deleted = create_open_task("Deleted", page_on: @today).tap(&:soft_delete!)
    foreign = create_open_task("Foreign", page_on: @today, user: users(:two))

    [ future, done ].each do |parent|
      assert_no_difference -> { Entry.count } do
        post children_entry_path(parent), params: { line: "child", default_kind: "task" }
      end
      assert_redirected_to(parent == future ? future_log_path : daily_log_path(date: @today.iso8601))
      assert_equal "That entry can't do that.", flash[:alert]
    end

    [ deleted, foreign ].each do |parent|
      post children_entry_path(parent), params: { line: "child", default_kind: "task" }
      assert_response :not_found
    end
  end

  test "inspiration renders through the one shared accessible signifier" do
    note = @user.entries.create!(kind: "note", state: nil, text: "Inspired", inspiration: true,
      priority: false, tags: [], page_kind: "daily", page_on: @today)
    both = create_open_task("Both", page_on: @today)
    both.update!(priority: true, inspiration: true)

    get daily_log_path(date: @today.iso8601)

    assert_select "#entry_#{note.id} .entry__signifier[aria-label='Inspiration']", text: "!"
    assert_select "#entry_#{both.id} .entry__signifier[aria-label='Priority and inspiration']", text: "*!"
  end
end
