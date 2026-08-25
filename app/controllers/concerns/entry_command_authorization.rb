# Defines which persisted page residencies admit each routed Entry command, and
# which of those commands a given row may actually be offered.
# Lifecycle state, kind, and structural movement remain Entry's responsibility.
module EntryCommandAuthorization
  extend ActiveSupport::Concern

  COMMAND_RESIDENCIES = {
    "complete" => %w[daily monthly_calendar monthly_tasks collection],
    "reopen" => %w[daily monthly_calendar monthly_tasks collection],
    "strike" => %w[daily monthly_calendar monthly_tasks collection],
    "migrate" => %w[daily monthly_calendar monthly_tasks],
    "schedule" => %w[daily monthly_calendar monthly_tasks],
    "move_to_collection" => %w[daily monthly_calendar monthly_tasks]
  }.transform_values(&:freeze).freeze
  # What a task's own lifecycle could support, before residency narrows it, in
  # the order a strip renders them. A state absent here - a migrated task -
  # supports nothing.
  TASK_COMMANDS_BY_STATE = {
    "open" => %w[complete strike migrate schedule move_to_collection],
    "done" => %w[reopen],
    "struck" => %w[reopen]
  }.transform_values(&:freeze).freeze
  # Events may schedule or move while notes may move; either becomes final
  # at this residency as soon as it has a successor.
  EVENT_COMMANDS = %w[schedule move_to_collection].freeze
  NOTE_COMMANDS = %w[move_to_collection].freeze
  NON_TASK_COMMANDS_BY_KIND = {
    "event" => EVENT_COMMANDS,
    "note" => NOTE_COMMANDS
  }.freeze
  NO_RESIDENCIES = [].freeze
  NO_COMMANDS = [].freeze

  included do
    helper_method :entry_command_allowed?, :offered_entry_commands
  end

  private

  # Unknown commands have no residency row and are refused by default.
  def entry_command_allowed?(entry, command)
    COMMAND_RESIDENCIES.fetch(command.to_s, NO_RESIDENCIES).include?(entry.page_kind)
  end

  # Every command this row may be offered: what its lifecycle supports, kept
  # only where its residency admits it. A row's toggle and the strip behind it
  # both read this one list, so a row can never become a toggle over a strip
  # with nothing in it.
  def offered_entry_commands(entry)
    lifecycle_commands(entry).select { |command| entry_command_allowed?(entry, command) }
  end

  def lifecycle_commands(entry)
    commands = if entry.kind == "task"
      TASK_COMMANDS_BY_STATE.fetch(entry.state, NO_COMMANDS)
    else
      NON_TASK_COMMANDS_BY_KIND.fetch(entry.kind, NO_COMMANDS)
    end

    entry.successor ? NO_COMMANDS : commands
  end
end
