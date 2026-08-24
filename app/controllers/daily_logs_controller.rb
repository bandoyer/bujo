# Renders a dated view of the signed-in user's journal.
class DailyLogsController < ApplicationController
  include DailyLogging

  # Shows an ISO-dated log, defaulting invalid and absent dates to today.
  def show
    @date = date_or_today(params[:date])
    @today = Time.zone.today
    @entries = Current.user.entries.daily_log(@date)
    @open_task_count = open_task_count_on(@date)
  end
end
