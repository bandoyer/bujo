require "test_helper"

# Pins the one capture exception owned by Monthly Migration without widening
# the ordinary Monthly Tasks writing surface.
class MonthlyMigrationCaptureTest < ActiveSupport::TestCase
  AS_OF = Date.new(2026, 8, 26)

  test "the ritual admits task capture through the next target month only" do
    user = users(:one)

    [ AS_OF.prev_month.beginning_of_month, AS_OF.beginning_of_month, AS_OF.next_month.beginning_of_month ].each do |target_month|
      entry = Entry.capture!(
        "plan #{target_month.strftime('%B')}",
        user: user,
        today: AS_OF,
        as_of: AS_OF,
        page_kind: "monthly_tasks",
        page_on: target_month,
        admission_context: :monthly_migration,
        target_month: target_month
      )

      assert_equal [ "task", "open", "monthly_tasks", target_month.beginning_of_month ],
        entry.values_at(:kind, :state, :page_kind, :page_on)
      assert_uuid_v7 entry.id
      assert_nil entry.hlc
      assert_nil entry.server_seq
    end

    assert_raises ActiveRecord::RecordInvalid do
      Entry.capture!(
        "plan October",
        user: user,
        today: AS_OF,
        as_of: AS_OF,
        page_kind: "monthly_tasks",
        page_on: Date.new(2026, 10, 1),
        admission_context: :monthly_migration,
        target_month: Date.new(2026, 10, 1)
      )
    end
  end

  test "the exception is exact to the derived target Tasks placement" do
    user = users(:one)
    target_month = AS_OF.next_month.beginning_of_month

    assert_raises ActiveRecord::RecordInvalid do
      Entry.capture!(
        "ordinary next-month task",
        user: user,
        today: AS_OF,
        as_of: AS_OF,
        page_kind: "monthly_tasks",
        page_on: target_month
      )
    end

    assert_raises ActiveRecord::RecordInvalid do
      Entry.capture!(
        "crafted placement",
        user: user,
        today: AS_OF,
        as_of: AS_OF,
        page_kind: "monthly_tasks",
        page_on: target_month,
        admission_context: :monthly_migration,
        target_month: AS_OF.beginning_of_month
      )
    end

    assert_raises ActiveRecord::RecordInvalid do
      Entry.capture!(
        "- explicit note",
        user: user,
        today: AS_OF,
        as_of: AS_OF,
        page_kind: "monthly_tasks",
        page_on: target_month,
        admission_context: :monthly_migration,
        target_month: target_month
      )
    end

    assert_nil Entry.capture!(
      "   ",
      user: user,
      today: AS_OF,
      as_of: AS_OF,
      page_kind: "monthly_tasks",
      page_on: target_month,
      admission_context: :monthly_migration,
      target_month: target_month
    )
  end

  test "the capture predicate remains the ordinary screen contract" do
    target_month = AS_OF.next_month.beginning_of_month

    assert_not Entry.capture_admitted?(
      page_kind: "monthly_tasks",
      page_on: target_month,
      as_of: AS_OF
    )
  end
end
