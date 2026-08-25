# Connects Daily Log forms to the existing entry capture and lifecycle API.
class EntriesController < ApplicationController
  include DailyLogging

  # Form values accepted as parser default kinds.
  DEFAULT_KINDS = %w[task event note].freeze

  before_action :set_entry, except: :create
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change

  # Captures a rapid-log line onto the explicitly requested journal page.
  def create
    @capture_date = requested_capture_date
    return refuse_capture unless @capture_date

    @entry = Entry.capture!(
      params[:line],
      user: Current.user,
      today: @capture_date,
      default_kind: default_kind
    )
    place_entry_in_future_log
    @open_task_count = open_task_count_on(@capture_date)

    respond_to do |format|
      format.turbo_stream { render future_placement? ? :create_future : :create }
      format.html { redirect_to capture_destination }
    end
  end

  # Marks an open task done.
  def complete
    @entry.complete!
    redirect_to_viewed_day
  end

  # Restores a done or struck task to open.
  def reopen
    @entry.reopen!
    redirect_to_viewed_day
  end

  # Strikes an open task while retaining it in the log.
  def strike
    @entry.strike!
    redirect_to_viewed_day
  end

  # Migrates an open task to the first day of the viewed day's next month.
  def migrate
    @entry.migrate_to!(logged_on: viewed_date.next_month.beginning_of_month)
    redirect_to_viewed_day
  end

  # Schedules an open task on the date the form supplied.
  def schedule
    date = requested_schedule_date
    return refuse_lifecycle_change unless date

    @entry.schedule_to!(occurs_on: date)
    redirect_to_viewed_day
  end

  private

  def set_entry
    @entry = Current.user.entries.find(params[:id])
  end

  def default_kind
    candidate = params[:default_kind]
    DEFAULT_KINDS.include?(candidate) ? candidate.to_sym : :task
  end

  # A missing or malformed page date is rejected: falling back to the clock
  # would silently write a valid entry onto the wrong journal page.
  def requested_capture_date
    Date.iso8601(params[:on].to_s)
  rescue Date::Error
    nil
  end

  def future_placement?
    params[:placement] == "future"
  end

  # Future placement uses the same parser and capture bridge as a Daily Log,
  # then pins the calendar date to the month-header gesture's chosen day.
  def place_entry_in_future_log
    @entry&.update!(occurs_on: @capture_date) if future_placement?
  end

  def capture_destination
    return future_log_path if future_placement?

    daily_log_path(date: @capture_date.iso8601)
  end

  def viewed_date
    @viewed_date ||= date_or_today(params[:viewed_on])
  end

  def redirect_to_viewed_day(**response_options)
    redirect_to daily_log_path(date: viewed_date.iso8601), **response_options
  end

  # The day the form asked for, or nil when it sent nothing usable. An absent
  # or non-ISO date is a refusal rather than a day to fall back to:
  # date_or_today's default belongs to choosing a screen to display, never to
  # moving an entry.
  def requested_schedule_date
    Date.iso8601(params[:date].to_s)
  rescue Date::Error
    nil
  end

  # An illegal transition and an unusable date read the same to the reader:
  # the entry did not move. A crafted or incomplete form must read as a
  # refusal, never as a 400 or a 500 - this is a form, not an API.
  def refuse_lifecycle_change
    redirect_to_viewed_day(alert: "That entry can't do that.")
  end

  # Turbo refusals leave the submitting reveal open; ordinary form fallbacks
  # return to the request's page because the rejected value cannot route them.
  def refuse_capture
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "That entry can't do that."
        render :capture_refused, status: :unprocessable_entity
      end
      format.html do
        redirect_back fallback_location: root_path, alert: "That entry can't do that."
      end
    end
  end
end
