# Guides one signed-in reader through a target month's derived migration work.
# The ritual persists only Entry lifecycle changes and append-only successors;
# its stages and completion are recomputed on every request.
class MonthlyMigrationsController < ApplicationController
  include JournalReading

  ITEM_ACTIONS = %i[
    outgoing_strike outgoing_tasks outgoing_collection outgoing_future
    future_strike future_tasks future_calendar
  ].freeze

  before_action :set_target_month
  before_action :set_migration_entry, only: ITEM_ACTIONS
  helper_method :target_param
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
    return present_checkpoint(
      "Review outgoing tasks",
      "No unresolved outgoing tasks.",
      "Scan the Future Log",
      monthly_migration_future_path(month: target_param)
    ) unless @candidate

    present_candidate("Review outgoing tasks", "Task tree", :outgoing)
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
      date = parsed_iso_date(params[:date])
      raise Entry::LifecycleError unless date

      # The existing movement boundary judges the month of its as_of input;
      # here that input intentionally names the ritual target, not wall month.
      @entry.move_to!(page_kind: "future", page_on: nil, occurs_on: date, as_of: @target_month)
    end
  end

  # Shows the first due Future root, or the explicit empty Future checkpoint.
  def future
    return redirect_to(canonical_stage_path) if outgoing_candidates.any?

    @candidate = future_candidates.first
    return present_checkpoint(
      "Scan the Future Log",
      "Nothing due for #{@target_month.strftime('%B')}.",
      "Finish Monthly Migration",
      monthly_migration_complete_path(month: target_param)
    ) unless @candidate

    present_candidate("Scan the Future Log", "Due Future tree", :future)
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
    redirect_to canonical_stage_path if unresolved_work?
  end

  private

  def set_target_month
    @target_month = parsed_month(params[:month])
    return render_migration_not_found unless Entry.migration_target_admitted?(@target_month, as_of: @today)

    @source_month = @target_month.prev_month
  end

  def set_migration_entry
    @entry = user_entries.kept.find(params[:id])
  end

  def load_target_tasks
    @target_entries = user_entries.monthly_tasks(@target_month)
  end

  def outgoing_candidates
    outgoing_roots.flat_map { |root| kept_resident_tree(root) }.select do |entry|
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

  def future_candidates
    user_entries.future_log.where(occurs_on: @target_month.all_month).select do |entry|
      entry.successor.nil? && future_candidate_state?(entry)
    end
  end

  def future_candidate_state?(entry)
    (entry.kind == "task" && entry.state == "open") || (entry.kind == "event" && entry.state.nil?)
  end

  def unresolved_work?
    outgoing_candidates.any? || future_candidates.any?
  end

  def present_candidate(stage, tree_label, review_stage)
    @candidate_root = resident_root(@candidate)
    @stage = stage
    @source_label = migration_source_label(@candidate)
    @tree_label = tree_label
    @review_stage = review_stage
    render :review
  end

  def present_checkpoint(stage, message, link_text, path)
    @stage = stage
    @checkpoint_message = message
    @checkpoint_link_text = link_text
    @checkpoint_path = path
    render :checkpoint
  end

  def resolve_outgoing(&action)
    resolve_ritual_item(action, monthly_migration_outgoing_path(month: target_param)) do
      outgoing_candidates.first == @entry
    end
  end

  def resolve_future(kind, &action)
    resolve_ritual_item(action, monthly_migration_future_path(month: target_param)) do
      outgoing_candidates.none? && future_candidates.first == @entry && @entry.kind == kind
    end
  end

  def resolve_ritual_item(action, return_path)
    resolved = Entry.transaction do
      next false unless yield

      action.call
      true
    end
    return refuse_command unless resolved

    redirect_to return_path
  end

  def canonical_stage_path
    return monthly_migration_outgoing_path(month: target_param) if outgoing_candidates.any?

    monthly_migration_future_path(month: target_param)
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
    when "future"
      "Future Log · #{entry.occurs_on.strftime('%B %-d, %Y')}"
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
