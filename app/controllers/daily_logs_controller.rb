# Renders a dated view of the signed-in user's journal.
class DailyLogsController < ApplicationController
  include DailyLogging

  # Shows an ISO-dated log, defaulting invalid and absent dates to today.
  def show
    @date = date_or_today(params[:date])
    @entries = daily_log_entries(@date)
    @open_task_count = open_task_count_on(@date)
    @capture_open = Entry.capture_admitted?(page_kind: "daily", page_on: @date, as_of: @today)
  end
end
