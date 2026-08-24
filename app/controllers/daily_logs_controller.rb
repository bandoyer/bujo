# Renders a dated view of the signed-in user's journal.
class DailyLogsController < ApplicationController
  # Shows an ISO-dated log, defaulting invalid and absent dates to today.
  def show
    @date = date_or_today(params[:date])
    @entries = Current.user.entries.daily_log(@date)
    @open_task_count = @entries.open_tasks.count
  end
end
