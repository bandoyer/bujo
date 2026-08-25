# The signed-in reader's entry relation, shared by every journal screen.
module JournalReading
  extend ActiveSupport::Concern

  included do
    before_action :snapshot_today
  end

  private

  # One clock reading serves the whole request, so a screen's affordances and
  # the admission rules behind them cannot disagree about which day it is.
  # Controllers are the only layer that reads the clock at all.
  def snapshot_today
    @today = Time.zone.today
  end

  # Every log query begins from the authenticated user's journal.
  def user_entries
    Current.user.entries
  end

  # Returns every kept id beneath the supplied resident roots, matching the
  # recursive partial's visibility boundary exactly.
  def rendered_entry_ids(entries)
    entries.flat_map { |entry| [ entry.id, *rendered_entry_ids(entry.children.kept) ] }
  end

  # Counts open tasks among the ids a page actually renders.
  def open_task_count(rendered_ids)
    user_entries.open_tasks.where(id: rendered_ids).count
  end
end
