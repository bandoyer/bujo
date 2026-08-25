# Renders the signed-in reader's continuous runway of future entries.
class FutureLogsController < ApplicationController
  include JournalReading
  include FutureLogTargets

  # Empty month headers keep this much runway visible beyond today.
  RUNWAY_MONTH_COUNT = 6

  helper_method :month_add_open?

  # Shows every occupied month plus six writable months after the current one.
  def show
    @today = Time.zone.today
    @entries_by_month = future_entries.group_by { |entry| entry.occurs_on.beginning_of_month }
    @months = (runway_months + @entries_by_month.keys).uniq.sort
  end

  private

  # Whether a runway month takes new entries, asked of the domain so the add
  # control and the server's refusal cannot answer the question differently.
  def month_add_open?(month)
    Entry.capture_admitted?(page_kind: "future", occurs_on: month, as_of: @today)
  end

  def future_entries
    user_entries.future_log
  end

  def runway_months
    first_month = @today.beginning_of_month.next_month
    RUNWAY_MONTH_COUNT.times.map { |offset| first_month >> offset }
  end
end
