# Renders the signed-in reader's continuous runway of future entries.
class FutureLogsController < ApplicationController
  include JournalReading
  include FutureLogTargets

  # Empty month headers keep this much runway visible beyond today.
  RUNWAY_MONTH_COUNT = 6

  # Shows every occupied month plus six writable months after the current one.
  def show
    @today = Time.zone.today
    @entries_by_month = future_entries.group_by { |entry| entry.occurs_on.beginning_of_month }
    @months = (runway_months + @entries_by_month.keys).uniq.sort
  end

  private

  def future_entries
    user_entries.future_log
  end

  def runway_months
    first_month = @today.beginning_of_month.next_month
    RUNWAY_MONTH_COUNT.times.map { |offset| first_month >> offset }
  end
end
