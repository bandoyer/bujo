# Connects page gestures to Entry capture and append-only lifecycle commands.
class EntriesController < ApplicationController
  include DailyLogging
  include FutureLogTargets

  # Parser defaults accepted from capture forms.
  DEFAULT_KINDS = %w[task event note].freeze
  # Page placements directly writable through this web controller.
  PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future].freeze
  # Resident pages that expose outbound movement in this slice.
  ACTION_PAGE_KINDS = %w[daily monthly_calendar monthly_tasks].freeze
  # One reader-facing refusal for every rejected command.
  REFUSAL_ALERT = "That entry can't do that.".freeze

  before_action :set_entry, except: :create
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change

  # Captures a rapid-log line on the page selected by the gesture.
  def create
    @capture_date = requested_date(:on)
    @placement = requested_placement
    return refuse_capture unless @capture_date

    @entry = capture_entry
    prepare_capture_response
    respond_to_capture
  rescue ActiveRecord::RecordInvalid
    refuse_capture
  end

  # Marks an open task done.
  def complete
    @entry.complete!
    redirect_to_viewed_page
  end

  # Restores a done or struck task to open.
  def reopen
    @entry.reopen!
    redirect_to_viewed_page
  end

  # Strikes an open task while retaining it on its page.
  def strike
    @entry.strike!
    redirect_to_viewed_page
  end

  # Carries an eligible task to the Tasks page after its resident month.
  def migrate
    return refuse_lifecycle_change unless @entry.page_on

    destination_month = @entry.page_on.next_month.beginning_of_month
    @entry.move_to!(
      page_kind: "monthly_tasks",
      page_on: destination_month,
      as_of: today
    )
    redirect_to_viewed_page
  end

  # Schedules an eligible task or event into the Future Log.
  def schedule
    date = requested_date(:date)
    eligible_kind = @entry.kind.in?(%w[task event])
    eligible_page = @entry.page_kind.in?(ACTION_PAGE_KINDS)
    return refuse_lifecycle_change unless date && eligible_kind && eligible_page

    @entry.move_to!(
      page_kind: "future",
      page_on: nil,
      occurs_on: date,
      as_of: today
    )
    redirect_to_viewed_page
  end

  private

  def set_entry
    @entry = user_entries.find(params[:id])
  end

  def capture_entry
    Entry.capture!(
      params[:line],
      user: Current.user,
      today: parser_today,
      as_of: today,
      default_kind: default_kind,
      **placement_attributes
    )
  end

  def requested_placement
    params[:placement].presence_in(PAGE_KINDS) || "daily"
  end

  def placement_attributes
    case @placement
    when "monthly_calendar"
      { page_kind: @placement, page_on: @capture_date.beginning_of_month, occurs_on: @capture_date }
    when "monthly_tasks"
      { page_kind: @placement, page_on: @capture_date.beginning_of_month }
    when "future"
      { page_kind: @placement, page_on: nil, occurs_on: @capture_date }
    else
      { page_kind: "daily", page_on: @capture_date }
    end
  end

  def parser_today
    @placement == "monthly_tasks" ? today : @capture_date
  end

  def default_kind
    candidate = params[:default_kind]
    DEFAULT_KINDS.include?(candidate) ? candidate.to_sym : :task
  end

  # The request owns one clock snapshot for every admission decision.
  def today
    @today ||= Time.zone.today
  end

  def prepare_capture_response
    return prepare_future_response if @placement == "future"
    prepare_daily_response if @placement == "daily"
  end

  def prepare_future_response
    return unless @entry

    @future_month_entries = user_entries.future_log.where(occurs_on: @capture_date.all_month)
  end

  def prepare_daily_response
    @open_task_count = open_task_count_on(@capture_date)
  end

  def respond_to_capture
    respond_to do |format|
      format.turbo_stream do
        if @placement.in?(%w[daily future])
          render @placement == "future" ? :create_future : :create
        else
          redirect_to capture_destination, status: :see_other
        end
      end
      format.html { redirect_to capture_destination }
    end
  end

  def capture_destination
    case @placement
    when "future"
      future_log_path
    when "monthly_calendar"
      monthly_log_path(month: @capture_date.strftime("%Y-%m"))
    when "monthly_tasks"
      monthly_log_path(month: @capture_date.strftime("%Y-%m"), view: "tasks")
    else
      daily_log_path(date: @capture_date.iso8601)
    end
  end

  def viewed_date
    @viewed_date ||= date_or_today(params[:viewed_on])
  end

  def redirect_to_viewed_page(**response_options)
    destination = case params[:return_to]
    when "monthly_calendar"
      monthly_log_path(month: viewed_date.strftime("%Y-%m"))
    when "monthly_tasks"
      monthly_log_path(month: viewed_date.strftime("%Y-%m"), view: "tasks")
    else
      daily_log_path(date: viewed_date.iso8601)
    end
    redirect_to destination, **response_options
  end

  def requested_date(param_name)
    Date.iso8601(params[param_name].to_s)
  rescue Date::Error
    nil
  end

  def refuse_lifecycle_change
    redirect_to_viewed_page(alert: REFUSAL_ALERT)
  end

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
