# The day a Daily Log request is about, and what that day shows.
module DailyLogging
  extend ActiveSupport::Concern

  private

  # Reads an ISO date, falling back to today so an absent or crafted param
  # renders a day instead of an error page.
  def date_or_today(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    Time.zone.today
  end

  # The rows a day's log lists: the signed-in reader's root entries for it.
  def daily_log_entries(date)
    Current.user.entries.daily_log(date)
  end

  # The header count for a day: the open tasks logged at its root level.
  def open_task_count_on(date)
    daily_log_entries(date).open_tasks.count
  end
end
