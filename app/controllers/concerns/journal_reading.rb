# The signed-in reader's journal request: the day it is about, the relations
# it may read, and the one response a missing Collection gets.
module JournalReading
  extend ActiveSupport::Concern

  # The optional path segment is an exact ISO year-month, never a prefix.
  MONTH_PATTERN = /\A\d{4}-\d{2}\z/

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

  # The month the URL asked for, or nil when it carried anything else. The
  # pattern runs first because strptime accepts a prefix, so "2026-08x" would
  # otherwise parse; absent, malformed and out-of-range all arrive here as nil.
  def parsed_month(value)
    text = value.to_s
    return unless text.match?(MONTH_PATTERN)

    Date.strptime(text, "%Y-%m").beginning_of_month
  rescue Date::Error
    nil
  end

  # Reads an ISO date, or nil when the value is absent, malformed, or impossible.
  def parsed_iso_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  # Returns the kept descendants of one resident in depth-first capture order,
  # including the resident itself, matching the recursive partial's walk.
  def kept_resident_tree(entry)
    [ entry, *entry.children.kept.flat_map { |child| kept_resident_tree(child) } ]
  end

  # Walks persisted parent links to the tree root the source page rendered.
  def resident_root(entry)
    root = entry
    root = root.parent while root.parent
    root
  end

  # Returns every kept id beneath the supplied resident roots, matching the
  # recursive partial's visibility boundary exactly.
  def rendered_entry_ids(entries)
    entries.flat_map { |entry| kept_resident_tree(entry).map(&:id) }
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
