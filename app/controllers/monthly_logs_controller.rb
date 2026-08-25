# Renders the signed-in reader's calendar or task history for one month.
class MonthlyLogsController < ApplicationController
  include JournalReading

  # The optional path segment is an exact ISO year-month, never a prefix.
  MONTH_PATTERN = /\A\d{4}-\d{2}\z/

  # Shows a URL-selected month, defaulting crafted values to the current one.
  def show
    @today = Time.zone.today
    @month = month_or_current(params[:month])
    @view = params[:view] == "tasks" ? :tasks : :calendar
    @capture_open = @month <= @today.beginning_of_month

    @view == :tasks ? load_tasks : load_calendar
  end

  private

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
    @open_task_count = user_entries.open_tasks.where(id: rendered_ids).count
    @logged_task_count = rendered_ids.count
  end
end
