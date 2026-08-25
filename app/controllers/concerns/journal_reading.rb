# The signed-in reader's journal request: the day it is about, the relations
# it may read, and the one response a missing Collection gets.
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

  # Every Collection query begins from the authenticated user's journal.
  def user_collections
    Current.user.collections
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

  # The uniform missing state for any Collection lookup that failed, wherever
  # it failed. Every probe - malformed, unknown, foreign, soft-deleted - must
  # be answered byte for byte alike, which one definition guarantees and two
  # kept in step by hand do not. Turbo gestures get the same HTML page, since
  # a stream cannot carry a themed refusal a reader can read.
  def render_collection_not_found
    render "collections/not_found", formats: :html, status: :not_found
  end
end
