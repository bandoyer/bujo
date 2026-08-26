require "test_helper"

# Exercises correction through its conventional PATCH command, including
# canonical returns and hostile parameter refusal.
class EntryCorrectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @collection = @user.collections.create!(name: "Correction Topic")
    sign_in_as @user
  end

  test "PATCH corrects every editable field and returns to persisted residency" do
    day = Time.zone.today.prev_day
    entry = create_entry(page_kind: "daily", page_on: day, text: "before")

    patch entry_path(entry), params: {
      line: "* after +alpha tomorrow 13:20",
      default_kind: "event",
      viewed_on: "2035-11-20",
      return_to: "monthly_tasks"
    }

    assert_redirected_to daily_log_path(date: day.iso8601)
    assert_equal [ "event", nil, "after", true, %w[alpha], day.next_day, "13:20" ],
      entry.reload.values_at(:kind, :state, :text, :priority, :tags, :occurs_on, :time_of_day)
  end

  test "relative correction anchors to the rendered root day" do
    root_day = Time.zone.today.prev_month.beginning_of_month + 4.days
    root = create_entry(page_kind: "daily", page_on: root_day, kind: "event", state: nil)
    child = create_entry(page_kind: "daily", page_on: root_day, parent: root)

    patch entry_path(child), params: { line: "nested tomorrow", default_kind: "task" }

    assert_redirected_to daily_log_path(date: root_day.iso8601)
    assert_equal root_day.next_day, child.reload.occurs_on
  end

  test "crafted immutable ownership and history fields refuse the whole correction" do
    entry = create_entry(text: "unchanged")
    original = entry.attributes

    %w[id user_id page_kind page_on collection_id parent_id migrated_from_id created_at deleted_at hlc server_seq].each do |field|
      assert_no_difference -> { Entry.count } do
        patch entry_path(entry), params: {
          line: "must not change", default_kind: "task", field => "crafted"
        }
      end

      assert_redirected_to daily_log_path(date: entry.page_on.iso8601)
      assert_equal "That entry can't do that.", flash[:alert]
      assert_equal original, entry.reload.attributes
    end
  end

  test "invalid correction keeps the submitted line for the canonical page" do
    month = Time.zone.today.beginning_of_month
    entry = create_entry(
      page_kind: "monthly_calendar", page_on: month, occurs_on: Time.zone.today,
      text: "unchanged"
    )

    patch entry_path(entry), params: {
      line: "outside month #{month.next_month.iso8601}", default_kind: "task"
    }

    assert_redirected_to monthly_log_path(month: month.strftime("%Y-%m"))
    assert_equal "outside month #{month.next_month.iso8601}", flash[:edit_line]
    assert_equal entry.id, flash[:edit_entry_id]
    assert_equal "unchanged", entry.reload.text
  end

  test "missing foreign deleted and moved predecessors cannot be corrected" do
    foreign = users(:two).entries.create!(
      kind: "task", state: "open", text: "foreign secret", tags: [],
      page_kind: "daily", page_on: Time.zone.today
    )
    deleted = create_entry(text: "deleted secret")
    deleted.soft_delete!
    moved = create_entry(text: "history words")
    moved.move_to!(
      page_kind: "monthly_tasks", page_on: Time.zone.today.next_month.beginning_of_month,
      as_of: Time.zone.today
    )

    [ foreign, deleted ].each do |entry|
      patch entry_path(entry), params: { line: "leak", default_kind: "task" }
      assert_response :not_found
      assert_not_includes response.body, entry.text
    end

    original = moved.attributes
    patch entry_path(moved), params: { line: "rewrite", default_kind: "task" }
    assert_redirected_to daily_log_path(date: moved.page_on.iso8601)
    assert_equal original, moved.reload.attributes
  end

  test "Collection correction returns canonically and refuses an unavailable Collection" do
    entry = create_entry(page_kind: "collection", page_on: nil, collection: @collection)

    patch entry_path(entry), params: { line: "corrected", default_kind: "note", return_to: "monthly_tasks" }
    assert_redirected_to collection_path(@collection)
    assert_equal [ "note", nil, "corrected" ], entry.reload.values_at(:kind, :state, :text)

    @collection.update_column(:deleted_at, Time.current)
    patch entry_path(entry), params: { line: "hidden", default_kind: "note" }
    assert_response :not_found
    assert_select "h1", text: "Collection not found"
  end

  private

  def create_entry(overrides = {})
    @user.entries.create!({
      kind: "task", state: "open", text: "entry words", tags: [],
      page_kind: "daily", page_on: Time.zone.today
    }.merge(overrides))
  end
end
