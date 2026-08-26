# Guides one signed-in reader through a target month's derived migration work.
# The ritual persists only Entry lifecycle changes and append-only successors;
# its stages and completion are recomputed on every request.
class MonthlyMigrationsController < ApplicationController
  include JournalReading

  MONTH_PATTERN = /\A\d{4}-\d{2}\z/
  OUTGOING_ACTIONS = %i[outgoing_strike outgoing_tasks outgoing_collection outgoing_future].freeze
  FUTURE_ACTIONS = %i[future_strike future_tasks future_calendar].freeze
  ITEM_ACTIONS = (OUTGOING_ACTIONS + FUTURE_ACTIONS).freeze
  REFUSAL_ALERT = EntriesController::REFUSAL_ALERT

  before_action :set_target_month
  before_action :set_migration_entry, only: ITEM_ACTIONS
  helper_method :migration_source_label
  rescue_from Entry::LifecycleError, ActiveRecord::RecordInvalid, with: :refuse_command
  rescue_from ActiveRecord::RecordNotFound, with: :render_item_not_found

  # Shows the fresh-inventory setup for one admitted target month.
  def show
    load_target_tasks
  end

  # Captures one task through the shared parser and the named setup exception.
  def inventory
    @line = params[:line].to_s
    Entry.capture!(
      @line,
      user: Current.user,
      today: @today,
      as_of: @today,
      page_kind: "monthly_tasks",
      page_on: @target_month,
      admission_context: :monthly_migration,
      target_month: @target_month
    )
    redirect_to monthly_migration_path(month: target_param)
  rescue ActiveRecord::RecordInvalid
    load_target_tasks
    flash.now[:alert] = REFUSAL_ALERT
    render :show, status: :unprocessable_entity
  end

  # Shows the first unresolved outgoing task in its complete resident tree.
  def outgoing
    @candidate = outgoing_candidates.first
    return redirect_to(monthly_migration_future_path(month: target_param)) unless @candidate

    @candidate_root = resident_root(@candidate)
  end

  # Strikes the current outgoing task as no longer vital.
  def outgoing_strike
    resolve_outgoing { @entry.strike! }
  end

  # Rewrites the current outgoing task onto the target Tasks page.
  def outgoing_tasks
    resolve_outgoing do
      @entry.move_to!(page_kind: "monthly_tasks", page_on: @target_month, as_of: @today)
    end
  end

  # Rewrites the current outgoing task into one exact known Topic.
  def outgoing_collection
    resolve_outgoing do
      destination = user_collections.kept.with_exact_topic(params[:topic]).first
      raise Entry::LifecycleError unless destination

      @entry.move_to!(page_kind: "collection", page_on: nil, collection: destination, as_of: @today)
    end
  end

  # Schedules the current outgoing task beyond the target month's horizon.
  def outgoing_future
    resolve_outgoing do
      date = parsed_date(params[:date])
      raise Entry::LifecycleError unless date

      # The existing movement boundary judges the month of its as_of input;
      # here that input intentionally names the ritual target, not wall month.
      @entry.move_to!(page_kind: "future", page_on: nil, occurs_on: date, as_of: @target_month)
    end
  end

  # Shows the first due Future root, or the live complete state once empty.
  def future
    return redirect_to(monthly_migration_outgoing_path(month: target_param)) if outgoing_candidates.any?

    @candidate = future_candidates.first
    @candidate_root = @candidate
    render :complete unless @candidate
  end

  # Strikes one due Future task without creating a successor.
  def future_strike
    resolve_future("task") { @entry.strike! }
  end

  # Rewrites one due Future task onto target Monthly Tasks.
  def future_tasks
    resolve_future("task") do
      @entry.move_to!(page_kind: "monthly_tasks", page_on: @target_month, as_of: @today)
    end
  end

  # Rewrites one due Future event onto its dated target Calendar row.
  def future_calendar
    resolve_future("event") do
      @entry.move_to!(
        page_kind: "monthly_calendar",
        page_on: @target_month,
        occurs_on: @entry.occurs_on,
        as_of: @today
      )
    end
  end

  # Canonicalizes a copied completion URL to the earliest live stage.
  def complete
    return redirect_to(monthly_migration_outgoing_path(month: target_param)) if outgoing_candidates.any?

    redirect_to(monthly_migration_future_path(month: target_param)) if future_candidates.any?
  end

  private

  def set_target_month
    @target_month = parsed_month(params[:month])
    return render_migration_not_found unless admitted_target?

    @source_month = @target_month.prev_month
  end

  def set_migration_entry
    @entry = user_entries.kept.find(params[:id])
  end

  def parsed_month(value)
    return unless value.to_s.match?(MONTH_PATTERN)

    Date.strptime(value, "%Y-%m").beginning_of_month
  rescue Date::Error
    nil
  end

  def admitted_target?
    @target_month && @target_month <= @today.next_month.beginning_of_month
  end

  def load_target_tasks
    @target_entries = user_entries.monthly_tasks(@target_month)
  end

  def outgoing_candidates
    outgoing_roots.flat_map { |root| kept_tree(root) }.select do |entry|
      entry.kind == "task" && entry.state == "open" && entry.successor.nil?
    end
  end

  # Root groups are concatenated in paper reading order; each source scope and
  # recursive child relation already owns its deterministic capture order.
  def outgoing_roots
    roots = user_entries.monthly_calendar(@source_month).to_a
    roots.concat(user_entries.monthly_tasks(@source_month).to_a)
    @source_month.all_month.each { |day| roots.concat(user_entries.daily_log(day).to_a) }
    roots
  end

  def kept_tree(entry)
    [ entry, *entry.children.kept.flat_map { |child| kept_tree(child) } ]
  end

  def resident_root(entry)
    root = entry
    root = root.parent while root.parent
    root
  end

  def future_candidates
    user_entries.future_log.where(occurs_on: @target_month.all_month).select do |entry|
      entry.successor.nil? && future_candidate_state?(entry)
    end
  end

  def future_candidate_state?(entry)
    (entry.kind == "task" && entry.state == "open") || (entry.kind == "event" && entry.state.nil?)
  end

  def resolve_outgoing
    resolved = Entry.transaction do
      next false unless outgoing_candidates.first == @entry

      yield
      true
    end
    return refuse_command unless resolved

    redirect_to next_after_outgoing_path
  end

  def resolve_future(kind)
    resolved = Entry.transaction do
      next false if outgoing_candidates.any?
      next false unless future_candidates.first == @entry && @entry.kind == kind

      yield
      true
    end
    return refuse_command unless resolved

    redirect_to monthly_migration_future_path(month: target_param)
  end

  def next_after_outgoing_path
    if outgoing_candidates.any?
      monthly_migration_outgoing_path(month: target_param)
    else
      monthly_migration_future_path(month: target_param)
    end
  end

  def canonical_stage_path
    return monthly_migration_outgoing_path(month: target_param) if outgoing_candidates.any?

    monthly_migration_future_path(month: target_param)
  end

  def parsed_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def target_param
    @target_month.strftime("%Y-%m")
  end

  def migration_source_label(entry)
    case entry.page_kind
    when "monthly_calendar"
      "Monthly Calendar · #{entry.page_on.strftime('%B %Y')}"
    when "monthly_tasks"
      "Monthly Tasks · #{entry.page_on.strftime('%B %Y')}"
    else
      "Daily Log · #{entry.page_on.strftime('%B %-d, %Y')}"
    end
  end

  def refuse_command
    redirect_to canonical_stage_path, alert: REFUSAL_ALERT
  end

  def render_migration_not_found
    render :not_found, status: :not_found
  end

  def render_item_not_found
    render :item_not_found, status: :not_found
  end
end
