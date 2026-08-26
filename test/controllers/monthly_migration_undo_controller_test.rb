require "test_helper"

# Pins immediate ritual Undo to a revalidated, one-shot compensating command.
class MonthlyMigrationUndoControllerTest < ActionDispatch::IntegrationTest
  AS_OF = Date.new(2026, 8, 26)
  TARGET = Date.new(2026, 9, 1)
  SOURCE = Date.new(2026, 8, 1)

  setup do
    @user = users(:one)
    @user.entries.update_all(deleted_at: Time.current)
    sign_in_as @user
  end

  test "strike resolution offers one Undo that reopens the exact task" do
    task = create_entry(page_kind: "monthly_tasks", page_on: SOURCE)

    post strike_monthly_migration_outgoing_path(month: "2026-09", id: task)
    assert_redirected_to monthly_migration_outgoing_path(month: "2026-09")
    follow_redirect!
    assert_select ".monthly-migration__confirmation", text: /Struck/m
    assert_select ".monthly-migration__confirmation input[type='submit'][value='Undo']"
    form = css_select("form[action='#{undo_path}']").first
    assert form

    post undo_path, params: hidden_params(form)

    assert_redirected_to monthly_migration_outgoing_path(month: "2026-09")
    assert_equal "open", task.reload.state
    follow_redirect!
    assert_select "#entry_#{task.id}[aria-label='Review this task']"
    get monthly_migration_outgoing_path(month: "2026-09")
    assert_select ".monthly-migration__confirmation", count: 0
  end

  test "movement Undo appends a third row restoring exact Future date time and current words" do
    source = create_entry(
      page_kind: "future", page_on: nil, occurs_on: TARGET + 4.days,
      time_of_day: "18:10", text: "future source", tags: %w[old]
    )

    post tasks_monthly_migration_future_path(month: "2026-09", id: source)
    moved = source.reload.successor
    moved.update!(text: "current words", tags: %w[current])
    follow_redirect!
    form = css_select("form[action='#{undo_path}']").first

    assert_difference -> { @user.entries.count }, 1 do
      post undo_path, params: hidden_params(form)
    end

    restored = moved.reload.successor
    assert_equal [ source.id, moved.id ], [ moved.migrated_from_id, restored.migrated_from_id ]
    assert_equal [ "future", nil, source.occurs_on, "18:10", "current words", %w[current], "open" ],
      restored.values_at(:page_kind, :page_on, :occurs_on, :time_of_day, :text, :tags, :state)
    assert_equal "migrated", moved.state
    assert_uuid_v7 restored.id
  end

  test "every movement resolution can be compensated to its exact source" do
    collection = @user.collections.create!(name: "Undo Topic")
    cases = [
      [ :outgoing_tasks, -> { create_entry(page_kind: "daily", page_on: SOURCE + 2.days) }, {} ],
      [ :outgoing_collection, -> { create_entry(page_kind: "monthly_tasks", page_on: SOURCE) }, { topic: collection.name } ],
      [ :outgoing_future, -> { create_entry(page_kind: "daily", page_on: SOURCE + 3.days) },
        { date: TARGET.next_month.iso8601 } ],
      [ :future_calendar, -> {
        create_entry(kind: "event", state: nil, page_kind: "future", page_on: nil,
          occurs_on: TARGET + 5.days, time_of_day: "09:30")
      }, {} ]
    ]

    cases.each do |resolution, build_source, params|
      source = build_source.call
      post resolution_path(resolution, source), params: params
      moved = source.reload.successor
      follow_redirect!
      form = css_select("form[action='#{undo_path}']").first
      post undo_path, params: hidden_params(form)
      restored = moved.reload.successor

      assert_equal source.values_at(:page_kind, :page_on, :collection_id, :occurs_on, :time_of_day),
        restored.values_at(:page_kind, :page_on, :collection_id, :occurs_on, :time_of_day)
      restored.strike! if restored.kind == "task"
    end
  end

  test "stale forged foreign and tombstoned Undo claims refuse without writes" do
    source = create_entry(page_kind: "monthly_tasks", page_on: SOURCE)
    post tasks_monthly_migration_outgoing_path(month: "2026-09", id: source)
    moved = source.reload.successor
    moved.complete!
    original = Entry.unscoped.order(:id).map(&:attributes)

    post undo_path, params: {
      original_id: source.id, result_id: moved.id, resolution: "outgoing_tasks"
    }
    assert_redirected_to monthly_migration_future_path(month: "2026-09")
    assert_equal "That entry can't do that.", flash[:alert]
    assert_equal original, Entry.unscoped.order(:id).map(&:attributes)

    foreign = users(:two).entries.create!(
      kind: "task", state: "open", text: "foreign", tags: [],
      page_kind: "monthly_tasks", page_on: SOURCE
    )
    post undo_path, params: {
      original_id: foreign.id, result_id: foreign.id, resolution: "outgoing_strike"
    }
    assert_response :not_found

    moved.update_column(:deleted_at, Time.current)
    post undo_path, params: {
      original_id: source.id, result_id: moved.id, resolution: "outgoing_tasks"
    }
    assert_response :not_found
  end

  test "in-transaction revalidation refuses an unavailable Future strike" do
    task = create_entry(
      page_kind: "future", page_on: nil, occurs_on: TARGET + 2.days
    )
    task.strike!
    task.update_column(:deleted_at, Time.current)

    controller = MonthlyMigrationsController.new
    controller.instance_variable_set(:@target_month, TARGET)

    assert_equal @user, Current.user
    assert_not controller.send(:undo_admitted?, task, task, "future_strike")

    task.update_columns(deleted_at: nil, user_id: users(:two).id)
    assert_not controller.send(:undo_admitted?, task, task, "future_strike")
  end

  private

  def undo_path
    undo_monthly_migration_path(month: "2026-09")
  end

  def create_entry(overrides = {})
    @user.entries.create!({
      kind: "task", state: "open", text: "ritual entry #{SecureRandom.hex(2)}", tags: [],
      page_kind: "monthly_tasks", page_on: SOURCE
    }.merge(overrides))
  end

  def hidden_params(form)
    form.css("input[type='hidden']").to_h { |input| [ input["name"], input["value"] ] }
  end

  def resolution_path(resolution, entry)
    send("#{resolution}_path", entry)
  end

  def outgoing_tasks_path(entry)
    tasks_monthly_migration_outgoing_path(month: "2026-09", id: entry)
  end

  def outgoing_collection_path(entry)
    collection_monthly_migration_outgoing_path(month: "2026-09", id: entry)
  end

  def outgoing_future_path(entry)
    future_monthly_migration_outgoing_path(month: "2026-09", id: entry)
  end

  def future_calendar_path(entry)
    calendar_monthly_migration_future_path(month: "2026-09", id: entry)
  end
end
