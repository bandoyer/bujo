# Connects page gestures to Entry capture and append-only lifecycle commands.
class EntriesController < ApplicationController
  include DailyLogging
  include FutureLogTargets

  # Page placements directly writable through this web controller.
  WRITABLE_PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future collection].freeze
  # Param-driven return destinations retained for Daily and Monthly commands.
  RETURN_PAGE_KINDS = %w[daily monthly_calendar monthly_tasks].freeze
  # Reflection return symbols are navigation choices, never request-authored
  # URLs or placement authority.
  REFLECTION_RETURN_PATHS = {
    "reflection_morning" => :reflection_path,
    "reflection_evening" => :evening_reflection_path
  }.freeze
  # Placements whose page date cannot anchor a relative date, so the parser
  # reads the wall clock instead: a Tasks page names a month rather than a day,
  # and a Custom Collection carries no date at all.
  CLOCK_PARSED_PAGE_KINDS = %w[monthly_tasks collection].freeze
  # Commands whose safe refusal return derives from persisted residency.
  ENTRY_PAGE_REFUSALS = %w[update schedule children].freeze
  # Placements whose capture refreshes in place instead of re-rendering a screen.
  TURBO_CAPTURE_TEMPLATES = { "daily" => :create, "future" => :create_future }.freeze
  # Any presence of these ownership, residency, tree, history, deletion, or
  # dormant-sync claims refuses correction as a whole command.
  FORBIDDEN_CORRECTION_PARAMS = %w[
    id user_id page_kind page_on collection_id parent_id migrated_from_id
    created_at deleted_at hlc server_seq state
  ].freeze
  # Child capture accepts only the form's rapid-log inputs. Every journal field
  # derives from the route's current-user parent.
  CHILD_REQUEST_PARAMS = %w[authenticity_token line default_kind commit].freeze

  # Both filters cover every member action rather than naming them, so a
  # command added later arrives gated instead of silently reachable from any
  # page - the shape of the hole this guard exists to close.
  before_action :set_entry, except: :create
  before_action :require_actionable_residency, except: :create
  rescue_from ActiveRecord::RecordNotFound, with: :render_entry_not_found
  rescue_from Entry::LifecycleError, with: :refuse_lifecycle_change
  rescue_from ActiveRecord::RecordInvalid, with: :refuse_lifecycle_change

  # Captures a rapid-log line on the page selected by the gesture.
  def create
    @placement = requested_placement
    prepare_capture_placement
    return refuse_capture unless @capture_date

    @entry = capture_entry
    return refuse_capture if @entry.nil? && params[:line].present?

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

  # Corrects the current live row from one reparsed rapid-log line.
  def update
    @submitted_edit_line = params[:line].to_s
    raise Entry::LifecycleError if forbidden_correction_claim?

    kind = requested_kind
    parsed = Bujo::RapidLog.parse(
      @submitted_edit_line,
      today: correction_parser_today,
      default_kind: kind.to_sym
    )
    @entry.correct!(parsed, kind: kind)
    redirect_to_entry_page
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

  # Schedules an eligible task or event to Calendar later this month or Future
  # after this month, deriving every destination field from the submitted day.
  def schedule
    date = requested_date(:date)
    eligible_kind = @entry.kind.in?(Entry::ROOT_KINDS.fetch("future"))
    return refuse_lifecycle_change unless date && date > @today && eligible_kind

    destination = schedule_destination(date)
    @entry.move_to!(occurs_on: date, as_of: @today, **destination)
    redirect_to_entry_page
  end

  # Rewrites one eligible Daily or Monthly resident into an exact known
  # Collection while keeping the reader on the persisted source page.
  def move_to_collection
    destination = user_collections.kept.with_exact_topic(params[:topic]).first
    return refuse_lifecycle_change unless destination

    @entry.move_to!(
      page_kind: "collection",
      page_on: nil,
      collection: destination,
      as_of: @today
    )
    redirect_to_viewed_page
  end

  # Writes one rapid-log line beneath the routed persisted parent.
  def children
    @submitted_child_line = params[:line].to_s
    @submitted_child_kind = requested_kind
    raise Entry::LifecycleError if forbidden_child_claim?

    child = Entry.capture_child!(
      @submitted_child_line,
      parent: @entry,
      user: Current.user,
      today: correction_parser_today,
      as_of: @today,
      default_kind: @submitted_child_kind.to_sym
    )
    raise Entry::LifecycleError if child.nil? && @submitted_child_line.present?

    if child
      flash[:child_focus_id] = child.id
    else
      flash[:child_parent_id] = @entry.id
    end
    redirect_to_entry_page
  end

  private

  # Resolves the command's subject: the entry, and for a Collection resident
  # the Collection it persists in. Both lookups happen before any action body,
  # so a foreign or tombstoned row on either side is a missing resource rather
  # than a refusal, and the return destination is already in hand.
  def set_entry
    @entry = user_entries.kept.find(params[:id])
    @collection = user_collections.kept.find(@entry.collection_id) if @entry.page_kind == "collection"
  end

  def forbidden_correction_claim?
    [ request.request_parameters, request.query_parameters ].any? do |claims|
      correction_claim_keys(claims).intersect?(FORBIDDEN_CORRECTION_PARAMS)
    end
  end

  def forbidden_child_claim?
    [ request.request_parameters, request.query_parameters ].any? do |claims|
      claims.keys.any? { |key| !CHILD_REQUEST_PARAMS.include?(key) }
    end
  end

  def requested_kind
    params[:default_kind].presence_in(Entry::KINDS) || raise(Entry::LifecycleError)
  end

  def correction_claim_keys(claims)
    nested = claims["entry"]
    claims.keys + (nested.respond_to?(:keys) ? nested.keys : [])
  end

  def correction_parser_today
    root = resident_root(@entry)
    case root.page_kind
    when "daily" then root.page_on
    when "monthly_calendar", "future" then root.occurs_on
    else @today
    end
  end

  def schedule_destination(date)
    if date <= @today.end_of_month
      { page_kind: "monthly_calendar", page_on: @today.beginning_of_month }
    else
      { page_kind: "future", page_on: nil }
    end
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
    return "daily" if reflection_return

    params[:placement].presence_in(WRITABLE_PAGE_KINDS) || "daily"
  end

  def prepare_capture_placement
    if reflection_return
      @capture_date = @today
      return
    end

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
    remember_reflection_focus("capture")
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
    return redirect_to(capture_destination, status: :see_other) if reflection_return

    respond_to do |format|
      format.turbo_stream do
        template = TURBO_CAPTURE_TEMPLATES[@placement]
        template ? render(template) : redirect_to(capture_destination, status: :see_other)
      end
      format.html { redirect_to capture_destination }
    end
  end

  def capture_destination
    fallback = @placement == "collection" ? collection_path(@collection) : page_path(@placement, @capture_date)
    command_return_path(fallback)
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

  # A Collection resident returns to its own canonical page, derived from what
  # it persists, so no crafted parameter can send the reader elsewhere. Dated
  # pages keep the parameter-driven destination the reader navigated from.
  def redirect_to_viewed_page(**response_options)
    remember_reflection_focus("entry:#{@entry.id}")
    redirect_to command_return_path(viewed_page_path), **response_options
  end

  def redirect_to_entry_page(**response_options)
    remember_reflection_focus("entry:#{@entry.id}")
    redirect_to command_return_path(entry_page_path), **response_options
  end

  def viewed_page_path
    return collection_path(@collection) if @entry.page_kind == "collection"

    page_path(params[:return_to].presence_in(RETURN_PAGE_KINDS), viewed_date)
  end

  def reflection_return
    @reflection_return ||= params[:return_to].presence_in(REFLECTION_RETURN_PATHS.keys)
  end

  def reflection_destination
    public_send(REFLECTION_RETURN_PATHS.fetch(reflection_return))
  end

  def command_return_path(fallback)
    reflection_return ? reflection_destination : fallback
  end

  def entry_page_path
    return collection_path(@collection) if @entry.page_kind == "collection"

    page_path(@entry.page_kind, @entry.page_on || @entry.occurs_on || @today)
  end

  # Which lookup failed decides the response. A resolved Collection resident
  # whose Collection is gone gets the themed page that screen already shows;
  # a missing entry has no screen to theme, so it answers with the bare status.
  def render_entry_not_found
    return render_collection_not_found if @entry&.page_kind == "collection"

    head :not_found
  end

  def requested_date(param_name)
    parsed_iso_date(params[param_name])
  end

  def refuse_lifecycle_change
    remember_refused_form
    return redirect_to_entry_page(alert: REFUSAL_ALERT) if action_name.in?(ENTRY_PAGE_REFUSALS)

    redirect_to_viewed_page(alert: REFUSAL_ALERT)
  end

  def remember_refused_form
    remember_refused_edit if action_name == "update"
    remember_refused_child if action_name == "children"
  end

  def remember_refused_edit
    flash[:edit_entry_id] = @entry.id
    flash[:edit_line] = @submitted_edit_line || params[:line].to_s
  end

  def remember_refused_child
    flash[:child_parent_id] = @entry.id
    flash[:child_line] = @submitted_child_line || params[:line].to_s
    flash[:child_kind] = @submitted_child_kind || params[:default_kind].to_s
  end

  def refuse_capture
    return refuse_reflection_capture if reflection_return

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

  def refuse_reflection_capture
    flash[:alert] = REFUSAL_ALERT
    flash[:reflection_line] = params[:line].to_s
    flash[:reflection_kind] = default_kind.to_s
    remember_reflection_focus("capture")
    redirect_to reflection_destination, status: :see_other
  end

  def remember_reflection_focus(token)
    flash[:reflection_focus] = token if reflection_return
  end
end
