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

  # Whose journal every Daily Log query reads. Named once so the ownership
  # scope cannot be spelled out differently in two places.
  def user_entries
    Current.user.entries
  end

  # The rows a day's log lists: the signed-in reader's root entries for it.
  def daily_log_entries(date)
    user_entries.daily_log(date)
  end

  # The header count for a day: every open task in the tree the view renders.
  def open_task_count_on(date)
    rendered_ids = rendered_entry_ids(daily_log_entries(date))
    user_entries.open_tasks.where(id: rendered_ids).count
  end

  # Descendants appear with their top-most root regardless of their own date,
  # so follow the same kept child relations as the recursive entry partial.
  # Each entry contributes itself and everything rendered beneath it.
  def rendered_entry_ids(entries)
    entries.flat_map { |entry| [ entry.id, *rendered_entry_ids(entry.children.kept) ] }
  end
end
