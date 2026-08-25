# The signed-in reader's entry relation, shared by every journal screen.
module JournalReading
  extend ActiveSupport::Concern

  private

  # Every log query begins from the authenticated user's journal.
  def user_entries
    Current.user.entries
  end

  # Returns every kept id beneath the supplied resident roots, matching the
  # recursive partial's visibility boundary exactly.
  def rendered_entry_ids(entries)
    entries.flat_map { |entry| [ entry.id, *rendered_entry_ids(entry.children.kept) ] }
  end

  # Counts open tasks within the trees a page actually renders.
  def open_task_count(entries)
    user_entries.open_tasks.where(id: rendered_entry_ids(entries)).count
  end
end
