# Connects Daily Log forms to the existing entry capture and lifecycle API.
class EntriesController < ApplicationController
  include DailyLogging

  # Form values accepted as parser default kinds.
  DEFAULT_KINDS = %w[task event note].freeze

  before_action :set_entry, except: :create
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change

  # Captures a rapid-log line into today using an allowed default kind.
  def create
    @today = Time.zone.today
    @entry = Entry.capture!(
      params[:line],
      user: Current.user,
      today: @today,
      default_kind: default_kind
    )
    @open_task_count = open_task_count_on(@today)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to daily_log_path(date: @today.iso8601) }
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
end
