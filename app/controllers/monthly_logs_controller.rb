# Renders the signed-in reader's calendar or task history for one month.
class MonthlyLogsController < ApplicationController
  include JournalReading

  # The optional path segment is an exact ISO year-month, never a prefix.
  MONTH_PATTERN = /\A\d{4}-\d{2}\z/

  # Shows a URL-selected month, defaulting crafted values to the current one.
  def show
    @month = month_or_current(params[:month])
    @view = params[:view] == "tasks" ? :tasks : :calendar
    @capture_open = Entry.capture_admitted?(page_kind: viewed_page_kind, page_on: @month, as_of: @today)
    @migration_admitted = @month <= @today.next_month.beginning_of_month

    @view == :tasks ? load_tasks : load_calendar
  end

  private

  # The residency this month's selected view writes to and renders.
  def viewed_page_kind
    @view == :tasks ? "monthly_tasks" : "monthly_calendar"
  end

  def month_or_current(value)
    parsed_month(value.to_s) || @today.beginning_of_month
  end

  # The month the URL asked for, or nil when it carried anything else. The
  # pattern runs first because strptime accepts a prefix, so "2026-08x" would
  # otherwise parse; absent, malformed and out-of-range all arrive here as nil.
  def parsed_month(value)
    return unless value.match?(MONTH_PATTERN)

    Date.strptime(value, "%Y-%m").beginning_of_month
  rescue Date::Error
    nil
  end

  def load_calendar
    @entries_by_date = user_entries.monthly_calendar(@month).group_by(&:occurs_on)
  end

  def load_tasks
    @entries = user_entries.monthly_tasks(@month)
    rendered_ids = rendered_entry_ids(@entries)
    @open_task_count = open_task_count(rendered_ids)
    @logged_task_count = rendered_ids.count
  end
end
