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

  # The header count for a day: every open task in the tree the view renders.
  def open_task_count_on(date)
    entry_ids = rendered_entry_ids(daily_log_entries(date))
    Current.user.entries.open_tasks.where(id: entry_ids).count
  end

  # Descendants appear with their top-most root regardless of their own date,
  # so follow the same kept child relations as the recursive entry partial.
  def rendered_entry_ids(entries)
    entries.each_with_object([]) do |entry, ids|
      ids << entry.id
      ids.concat(rendered_entry_ids(entry.children.kept))
    end
  end
end
