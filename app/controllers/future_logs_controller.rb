# Renders the signed-in reader's continuous runway of future entries.
class FutureLogsController < ApplicationController
  include JournalReading
  include FutureLogTargets

  # Empty month headers keep this much runway visible beyond today.
  RUNWAY_MONTH_COUNT = 6

  # Shows upcoming entries within six visible months plus occupied later ones.
  def show
    @today = Time.zone.today
    @entries_by_month = future_entries.group_by { |entry| entry.occurs_on.beginning_of_month }
    @months = runway_months
  end

  private

  def future_entries
    user_entries.future_log(after: @today)
  end

  def runway_months
    first_month = first_runway_month
    runway = RUNWAY_MONTH_COUNT.times.map { |offset| first_month >> offset }
    runway + occupied_months_after(runway.last)
  end

  def first_runway_month
    current_month = @today.beginning_of_month
    @entries_by_month.key?(current_month) ? current_month : current_month.next_month
  end

  def occupied_months_after(month)
    @entries_by_month.keys.select { |occupied_month| occupied_month > month }.sort
  end
end
