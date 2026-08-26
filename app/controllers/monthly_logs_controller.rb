# Renders the signed-in reader's calendar or task history for one month.
class MonthlyLogsController < ApplicationController
  include JournalReading

  # Shows a URL-selected month, defaulting crafted values to the current one.
  def show
    @month = month_or_current(params[:month])
    @view = params[:view] == "tasks" ? :tasks : :calendar
    @capture_open = Entry.capture_admitted?(page_kind: viewed_page_kind, page_on: @month, as_of: @today)
    @migration_admitted = Entry.migration_target_admitted?(@month, as_of: @today)

    @view == :tasks ? load_tasks : load_calendar
  end

  private

  # The residency this month's selected view writes to and renders.
  def viewed_page_kind
    @view == :tasks ? "monthly_tasks" : "monthly_calendar"
  end

  def month_or_current(value)
    parsed_month(value) || @today.beginning_of_month
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
