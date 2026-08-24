# The day a Daily Log request is about, and what its header counts.
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

  # The header count for a day: the open tasks logged at its root level.
  def open_task_count_on(date)
    Current.user.entries.daily_log(date).open_tasks.count
  end
end
