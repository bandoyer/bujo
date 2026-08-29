# Defines which persisted page residencies admit each routed Entry command, and
# which of those commands a given row may actually be offered.
# Lifecycle state, kind, and structural movement remain Entry's responsibility.
module EntryCommandAuthorization
  extend ActiveSupport::Concern

  # The one reader-facing message for every refused entry command, generic or
  # ritual, so no controller has to reach into a peer for it.
  REFUSAL_ALERT = "That entry can't do that.".freeze

  COMMAND_RESIDENCIES = {
    "update" => Entry::PAGE_KINDS,
    "complete" => %w[daily monthly_calendar monthly_tasks collection],
    "reopen" => %w[daily monthly_calendar monthly_tasks collection],
    "strike" => %w[daily monthly_calendar monthly_tasks collection],
    "migrate" => %w[daily monthly_calendar monthly_tasks],
    "schedule" => %w[daily monthly_calendar monthly_tasks],
    "move_to_collection" => %w[daily monthly_calendar monthly_tasks],
    "children" => %w[daily monthly_calendar monthly_tasks collection]
  }.transform_values(&:freeze).freeze
  # What a task's own lifecycle could support, before residency narrows it, in
  # the order a strip renders them. A state absent here - a migrated task -
  # supports nothing.
  TASK_COMMANDS_BY_STATE = {
    "open" => %w[complete strike migrate schedule move_to_collection children],
    "done" => %w[reopen],
    "struck" => %w[reopen]
  }.transform_values(&:freeze).freeze
  # What an event or note supports. Neither varies by state - both carry NULL -
  # so kind alone keys them. A note's one command is the first it has ever had.
  NON_TASK_COMMANDS_BY_KIND = {
    "event" => %w[schedule move_to_collection],
    "note" => %w[move_to_collection]
  }.transform_values(&:freeze).freeze
  NO_RESIDENCIES = [].freeze
  NO_COMMANDS = [].freeze

  included do
    helper_method :entry_command_allowed?, :offered_entry_commands
  end

  private

  # Unknown commands have no residency row and are refused by default.
  # Child capture still consults that table, then the Entry predicate that
  # also guards the model command, so a view cannot offer what residency or
  # temporal admission would refuse.
  def entry_command_allowed?(entry, command)
    command = command.to_s
    return false unless COMMAND_RESIDENCIES.fetch(command, NO_RESIDENCIES).include?(entry.page_kind)
    return entry.child_capture_admitted?(as_of: @today) if command == "children"

    entry.successor.nil?
  end

  # Every command this row may be offered: what its lifecycle supports, kept
  # only where its residency admits it. A row's toggle and the strip behind it
  # both read this one list, so a row can never become a toggle over a strip
  # with nothing in it.
  def offered_entry_commands(entry)
    lifecycle_commands(entry).select do |command|
      (command != "complete" || entry.completable?) && entry_command_allowed?(entry, command)
    end
  end

  # An entry that has already moved is finished wherever it sits: the successor
  # carries the journal forward, so the predecessor offers nothing at all.
  def lifecycle_commands(entry)
    return NO_COMMANDS if entry.successor

    commands = if entry.kind == "task"
      TASK_COMMANDS_BY_STATE.fetch(entry.state, NO_COMMANDS)
    else
      NON_TASK_COMMANDS_BY_KIND.fetch(entry.kind, NO_COMMANDS)
    end

    [ "update", *commands ]
  end
end
