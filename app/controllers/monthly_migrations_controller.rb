# Guides one signed-in reader through a target month's derived migration work.
# The ritual persists only Entry lifecycle changes and append-only successors;
# its stages and completion are recomputed on every request.
class MonthlyMigrationsController < ApplicationController
  include JournalReading

  ITEM_ACTIONS = %i[
    outgoing_strike outgoing_tasks outgoing_collection outgoing_future
    future_strike future_tasks future_calendar
  ].freeze
  # Every ritual result whose one-shot offer may be revalidated by Undo.
  UNDO_RESOLUTIONS = ITEM_ACTIONS.map(&:to_s).freeze
  # Destination predicates for movement results, keyed by the resolution the
  # ritual actually offered rather than trusting a submitted destination.
  MOVEMENT_UNDO_CHECKS = {
    "outgoing_tasks" => :target_tasks_result?,
    "future_tasks" => :target_tasks_result?,
    "outgoing_collection" => :collection_result?,
    "outgoing_future" => :future_result?,
    "future_calendar" => :calendar_result?
  }.freeze

  before_action :set_target_month
  before_action :set_migration_entry, only: ITEM_ACTIONS
  helper_method :target_param
  rescue_from Entry::LifecycleError, ActiveRecord::RecordInvalid,
    ActiveRecord::RecordNotUnique, with: :refuse_command
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
    stage = "Review outgoing tasks"
    if @candidate
      present_candidate(stage, "Task tree", :outgoing)
    else
      present_checkpoint(
        stage: stage,
        message: "No unresolved outgoing tasks.",
        link_text: "Scan the Future Log",
        path: monthly_migration_future_path(month: target_param)
      )
    end
  end

  # Strikes the current outgoing task as no longer vital.
  def outgoing_strike
    resolve_outgoing(:outgoing_strike) { @entry.strike! }
  end

  # Rewrites the current outgoing task onto the target Tasks page.
  def outgoing_tasks
    resolve_outgoing(:outgoing_tasks) do
      @entry.move_to!(page_kind: "monthly_tasks", page_on: @target_month, as_of: @today)
    end
  end

  # Rewrites the current outgoing task into one exact known Topic.
  def outgoing_collection
    resolve_outgoing(:outgoing_collection) do
      destination = user_collections.kept.with_exact_topic(params[:topic]).first
      raise Entry::LifecycleError unless destination

      @entry.move_to!(page_kind: "collection", page_on: nil, collection: destination, as_of: @today)
    end
  end

  # Schedules the current outgoing task beyond the target month's horizon.
  def outgoing_future
    resolve_outgoing(:outgoing_future) do
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
    stage = "Scan the Future Log"
    if @candidate
      present_candidate(stage, "Due Future tree", :future)
    else
      present_checkpoint(
        stage: stage,
        message: "Nothing due for #{@target_month.strftime('%B')}.",
        link_text: "Finish Monthly Migration",
        path: monthly_migration_complete_path(month: target_param)
      )
    end
  end

  # Strikes one due Future task without creating a successor.
  def future_strike
    resolve_future("task", :future_strike) { @entry.strike! }
  end

  # Rewrites one due Future task onto target Monthly Tasks.
  def future_tasks
    resolve_future("task", :future_tasks) do
      @entry.move_to!(page_kind: "monthly_tasks", page_on: @target_month, as_of: @today)
    end
  end

  # Rewrites one due Future event onto its dated target Calendar row.
  def future_calendar
    resolve_future("event", :future_calendar) do
      @entry.move_to!(
        page_kind: "monthly_calendar",
        page_on: @target_month,
        occurs_on: @entry.occurs_on,
        as_of: @today
      )
    end
  end

  # Revalidates the one offered ritual result and either reopens its strike or
  # appends a compensating movement back to the exact persisted source.
  def undo
    resolution = params[:resolution].to_s
    raise Entry::LifecycleError unless UNDO_RESOLUTIONS.include?(resolution)

    original = user_entries.kept.find(params[:original_id])
    result = user_entries.kept.find(params[:result_id])
    Entry.transaction do
      [ original, result ].uniq.sort_by(&:id).each(&:lock!)
      raise Entry::LifecycleError unless undo_admitted?(original, result, resolution)

      strike_resolution?(resolution) ? original.reopen! : result.compensate_to!(original)
    end
    redirect_to canonical_stage_path
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
    outgoing_tree_entries.select do |entry|
      entry.kind == "task" && entry.unresolved? && entry.successor.nil?
    end
  end

  def outgoing_tree_entries
    outgoing_roots.flat_map { |root| kept_resident_tree(root) }
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
    Entry::ROOT_KINDS.fetch("future").include?(entry.kind) && entry.unresolved?
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

  def present_checkpoint(stage:, message:, link_text:, path:)
    @stage = stage
    @checkpoint_message = message
    @checkpoint_link_text = link_text
    @checkpoint_path = path
    render :checkpoint
  end

  def resolve_outgoing(resolution, &action)
    resolve_ritual_item(resolution, action, monthly_migration_outgoing_path(month: target_param)) do
      outgoing_candidates.first == @entry
    end
  end

  def resolve_future(kind, resolution, &action)
    resolve_ritual_item(resolution, action, monthly_migration_future_path(month: target_param)) do
      outgoing_candidates.none? && future_candidates.first == @entry && @entry.kind == kind
    end
  end

  def resolve_ritual_item(resolution, action, return_path)
    result = Entry.transaction do
      next false unless yield

      action.call
    end
    return refuse_command unless result

    offer_undo(resolution, result)
    redirect_to return_path
  end

  def offer_undo(resolution, result)
    resolution_name = resolution.to_s
    result_entry = strike_resolution?(resolution_name) ? @entry : result
    flash[:migration_undo] = {
      "message" => undo_message(resolution_name, result_entry),
      "original_id" => @entry.id,
      "result_id" => result_entry.id,
      "resolution" => resolution_name
    }
  end

  def undo_message(resolution, result)
    case resolution
    when "outgoing_strike", "future_strike" then "Struck."
    when "outgoing_tasks", "future_tasks" then "Moved to #{@target_month.strftime('%B')} Tasks."
    when "outgoing_collection" then "Moved to #{result.collection.name}."
    when "outgoing_future" then "Moved to Future · #{result.occurs_on.strftime('%b %-d')}."
    when "future_calendar" then "Moved to #{@target_month.strftime('%B')} Calendar."
    end
  end

  def undo_admitted?(original, result, resolution)
    original.reload
    result.reload
    return false unless resolution_source_admitted?(original, resolution)

    if strike_resolution?(resolution)
      original == result && original.kind == "task" && original.state == "struck" && original.successor.nil?
    else
      movement_undo_admitted?(original, result, resolution)
    end
  end

  def resolution_source_admitted?(original, resolution)
    if resolution.start_with?("outgoing_")
      original.kind == "task" && outgoing_source_ids.include?(original.id)
    else
      future_source_admitted?(original)
    end
  end

  def outgoing_source_ids
    @outgoing_source_ids ||= outgoing_tree_entries.map(&:id)
  end

  def future_source_admitted?(original)
    original.parent_id.nil? && original.page_kind == "future" &&
      original.occurs_on && @target_month.all_month.cover?(original.occurs_on)
  end

  def movement_undo_admitted?(original, result, resolution)
    return false unless result.current_successor_of?(original)
    return false unless result.unresolved?

    resolution_destination_matches?(original, result, resolution)
  end

  def resolution_destination_matches?(original, result, resolution)
    check = MOVEMENT_UNDO_CHECKS[resolution]
    check ? send(check, original, result) : false
  end

  def target_tasks_result?(_original, result)
    result.kind == "task" && result.page_kind == "monthly_tasks" && result.page_on == @target_month
  end

  def collection_result?(_original, result)
    result.kind == "task" && result.page_kind == "collection" &&
      user_collections.kept.exists?(result.collection_id)
  end

  def future_result?(_original, result)
    result.kind == "task" && result.page_kind == "future" &&
      result.occurs_on && result.occurs_on > @target_month.end_of_month
  end

  def calendar_result?(original, result)
    original.kind == "event" && result.kind == "event" &&
      result.page_kind == "monthly_calendar" && result.page_on == @target_month &&
      result.occurs_on == original.occurs_on
  end

  def strike_resolution?(resolution)
    resolution.end_with?("_strike")
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
