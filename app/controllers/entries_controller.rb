# Connects Daily Log forms to the existing entry capture and lifecycle API.
class EntriesController < ApplicationController
  include DailyLogging
  include FutureLogTargets

  # Form values accepted as parser default kinds.
  DEFAULT_KINDS = %w[task event note].freeze
  # Every refusal reads the same to the reader: nothing was written or moved.
  REFUSAL_ALERT = "That entry can't do that.".freeze

  before_action :set_entry, except: :create
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change

  # Captures a rapid-log line onto the explicitly requested journal page.
  def create
    @capture_date = requested_date(:on)
    return refuse_capture unless capture_date_allowed?

    @entry = Entry.capture!(
      params[:line],
      user: Current.user,
      today: @capture_date,
      default_kind: default_kind
    )
    future_placement? ? prepare_future_response : prepare_daily_response

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
    date = requested_date(:date)
    return refuse_lifecycle_change unless date

    @entry.schedule_to!(occurs_on: date)
    redirect_to_viewed_day
  end

  private

  def set_entry
    @entry = user_entries.find(params[:id])
  end

  def default_kind
    candidate = params[:default_kind]
    DEFAULT_KINDS.include?(candidate) ? candidate.to_sym : :task
  end

  def future_placement?
    params[:placement] == "future"
  end

  # Read once per request, so the refusal guard and the relation behind the
  # response cannot disagree about where the runway starts.
  def today
    @today ||= Time.zone.today
  end

  # Only a month-header gesture is constrained to the runway's strictly future
  # dates. A Daily Log page deliberately accepts any valid date it displays.
  def capture_date_allowed?
    return false unless @capture_date
    return true unless future_placement?

    @capture_date > today
  end

  # Future placement pins the calendar day, then composes the live response
  # from the same ordered relation a full Future Log render reads, so a live
  # insert lands where a reload would put it.
  def prepare_future_response
    return unless @entry

    @entry.update!(occurs_on: @capture_date)
    @future_month_entries = user_entries
      .future_log(after: today)
      .where(occurs_on: @capture_date.all_month)
  end

  # The Daily Log's response carries its page's header count. The runway's
  # does not show one, and computing it would walk that day's entry tree for
  # a screen that never displays it.
  def prepare_daily_response
    @open_task_count = open_task_count_on(@capture_date)
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

  # The date a form asked for, or nil when it sent nothing usable. Absent and
  # malformed are refusals, never days to fall back to: date_or_today's default
  # belongs to choosing a screen to display, never to writing or moving an
  # entry. A capture that quietly lands on the wrong page is the worse failure.
  def requested_date(param_name)
    Date.iso8601(params[param_name].to_s)
  rescue Date::Error
    nil
  end

  # An illegal transition and an unusable date read the same to the reader:
  # the entry did not move. A crafted or incomplete form must read as a
  # refusal, never as a 400 or a 500 - this is a form, not an API.
  def refuse_lifecycle_change
    redirect_to_viewed_day(alert: REFUSAL_ALERT)
  end

  # Turbo refusals leave the submitting reveal open; ordinary form fallbacks
  # return to the request's page because the rejected value cannot route them.
  def refuse_capture
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = REFUSAL_ALERT
        render :capture_refused, status: :unprocessable_entity
      end
      format.html do
        redirect_back fallback_location: root_path, alert: REFUSAL_ALERT
      end
    end
  end
end
