# Defines which persisted page residencies admit each routed Entry command.
# Lifecycle state, kind, and structural movement remain Entry's responsibility.
module EntryCommandAuthorization
  extend ActiveSupport::Concern

  COMMAND_RESIDENCIES = {
    "complete" => %w[daily monthly_calendar monthly_tasks collection],
    "reopen" => %w[daily monthly_calendar monthly_tasks collection],
    "strike" => %w[daily monthly_calendar monthly_tasks collection],
    "migrate" => %w[daily monthly_calendar monthly_tasks],
    "schedule" => %w[daily monthly_calendar monthly_tasks]
  }.transform_values(&:freeze).freeze
  NO_RESIDENCIES = [].freeze

  included do
    helper_method :entry_command_allowed?
  end

  private

  # Unknown commands have no residency row and are refused by default.
  def entry_command_allowed?(entry, command)
    COMMAND_RESIDENCIES.fetch(command.to_s, NO_RESIDENCIES).include?(entry.page_kind)
  end
end
