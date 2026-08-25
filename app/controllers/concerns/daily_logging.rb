# The day a Daily Log request is about, and what that day shows.
module DailyLogging
  extend ActiveSupport::Concern
  include JournalReading

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
    user_entries.daily_log(date)
  end

  # The header count for a day: every open task in the tree the view renders.
  def open_task_count_on(date)
    open_task_count(daily_log_entries(date))
  end
end
