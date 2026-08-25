# Connects page gestures to Entry capture and append-only lifecycle commands.
class EntriesController < ApplicationController
  include DailyLogging
  include FutureLogTargets

  # Page placements directly writable through this web controller.
  WRITABLE_PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future collection].freeze
  # Param-driven return destinations retained for Daily and Monthly commands.
  RETURN_PAGE_KINDS = %w[daily monthly_calendar monthly_tasks].freeze
  # Placements whose page date cannot anchor a relative date, so the parser
  # reads the wall clock instead: a Tasks page names a month rather than a day,
  # and a Custom Collection carries no date at all.
  CLOCK_PARSED_PAGE_KINDS = %w[monthly_tasks collection].freeze
  # Placements whose capture refreshes in place instead of re-rendering a screen.
  TURBO_CAPTURE_TEMPLATES = { "daily" => :create, "future" => :create_future }.freeze
  # One reader-facing refusal for every rejected command.
  REFUSAL_ALERT = "That entry can't do that.".freeze

  # Both filters cover every member action rather than naming them, so a
  # command added later arrives gated instead of silently reachable from any
  # page - the shape of the hole this guard exists to close.
  before_action :set_entry, except: :create
  before_action :require_actionable_residency, except: :create
  rescue_from ActiveRecord::RecordNotFound, with: :render_entry_not_found
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change

  # Captures a rapid-log line on the page selected by the gesture.
  def create
    @placement = requested_placement
    prepare_capture_placement
    return refuse_capture unless @capture_date

    @entry = capture_entry
    prepare_capture_response
    respond_to_capture
  rescue ActiveRecord::RecordNotFound
    render_collection_not_found
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
    destination_month = @entry.page_on.next_month.beginning_of_month
    @entry.move_to!(
      page_kind: "monthly_tasks",
      page_on: destination_month,
      as_of: @today
    )
    redirect_to_viewed_page
  end

  # Schedules an eligible task or event into the Future Log.
  def schedule
    date = requested_date(:date)
    eligible_kind = @entry.kind.in?(Entry::ROOT_KINDS.fetch("future"))
    return refuse_lifecycle_change unless date && eligible_kind

    @entry.move_to!(
      page_kind: "future",
      page_on: nil,
      occurs_on: date,
      as_of: @today
    )
    redirect_to_viewed_page
  end

  private

  def set_entry
    @entry = user_entries.kept.find(params[:id])
    @collection = user_collections.kept.find(@entry.collection_id) if @entry.page_kind == "collection"
  end

  # Every routed member action crosses the policy before its body runs.
  def require_actionable_residency
    refuse_lifecycle_change unless entry_command_allowed?(@entry, action_name)
  end

  def capture_entry
    Entry.capture!(
      params[:line],
      user: Current.user,
      today: parser_today,
      as_of: @today,
      default_kind: default_kind,
      **placement_attributes
    )
  end

  def requested_placement
    params[:placement].presence_in(WRITABLE_PAGE_KINDS) || "daily"
  end

  def prepare_capture_placement
    if @placement == "collection"
      @collection = user_collections.kept.find(params[:collection_id])
      @capture_date = @today
    else
      @capture_date = requested_date(:on)
    end
  end

  def placement_attributes
    case @placement
    when "monthly_calendar"
      { page_kind: @placement, page_on: @capture_date.beginning_of_month, occurs_on: @capture_date }
    when "monthly_tasks"
      { page_kind: @placement, page_on: @capture_date.beginning_of_month }
    when "future"
      { page_kind: @placement, page_on: nil, occurs_on: @capture_date }
    when "collection"
      { page_kind: @placement, page_on: nil, collection: @collection }
    else
      { page_kind: "daily", page_on: @capture_date }
    end
  end

  def parser_today
    @placement.in?(CLOCK_PARSED_PAGE_KINDS) ? @today : @capture_date
  end

  def default_kind
    candidate = params[:default_kind]
    Entry::KINDS.include?(candidate) ? candidate.to_sym : :task
  end

  def prepare_capture_response
    case @placement
    when "future" then prepare_future_response
    when "daily" then prepare_daily_response
    end
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
        template = TURBO_CAPTURE_TEMPLATES[@placement]
        template ? render(template) : redirect_to(capture_destination, status: :see_other)
      end
      format.html { redirect_to capture_destination }
    end
  end

  def capture_destination
    return collection_path(@collection) if @placement == "collection"

    page_path(@placement, @capture_date)
  end

  # The screen showing one page kind, so a reader lands back on the page the
  # gesture belonged to. An unrecognised return_to falls back to the Daily Log.
  def page_path(page_kind, date)
    case page_kind
    when "future"
      future_log_path
    when "monthly_calendar"
      monthly_log_path(month: date.strftime("%Y-%m"))
    when "monthly_tasks"
      monthly_log_path(month: date.strftime("%Y-%m"), view: "tasks")
    else
      daily_log_path(date: date.iso8601)
    end
  end

  def viewed_date
    @viewed_date ||= date_or_today(params[:viewed_on])
  end

  def redirect_to_viewed_page(**response_options)
    return redirect_to(collection_path(@collection), **response_options) if @entry.page_kind == "collection"

    return_page = params[:return_to].presence_in(RETURN_PAGE_KINDS)
    redirect_to page_path(return_page, viewed_date), **response_options
  end

  def render_entry_not_found
    return render_collection_not_found if @entry&.page_kind == "collection"

    head :not_found
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
        if @collection
          redirect_to collection_path(@collection), alert: REFUSAL_ALERT
        else
          redirect_back fallback_location: root_path, alert: REFUSAL_ALERT
        end
      end
    end
  end
end
