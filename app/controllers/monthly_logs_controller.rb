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

    @view == :tasks ? load_tasks : load_calendar
  end

  private

  def month_or_current(value)
    month = value.to_s
    raise Date::Error unless month.match?(MONTH_PATTERN)

    Date.strptime(month, "%Y-%m").beginning_of_month
  rescue Date::Error
    @today.beginning_of_month
  end

  def load_calendar
    @entries_by_date = user_entries.monthly_calendar(@month).group_by(&:occurs_on)
  end

  def load_tasks
    @entries = user_entries.monthly_tasks(@month)
    @open_task_count = @entries.open_tasks.count
    @logged_task_count = @entries.count
  end
end
