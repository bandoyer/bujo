# Renders the current reader's live Morning and Evening reference lenses and
# authorizes the one priority gesture introduced by Daily Reflection.
class DailyReflectionsController < ApplicationController
  include JournalReading

  before_action :set_priority_entry, only: %i[mark_priority clear_priority]
  rescue_from ActiveRecord::RecordNotFound, with: :render_priority_not_found
  rescue_from Entry::LifecycleError, with: :refuse_priority_change

  # Shows the current month's dated-page review in paper reading order.
  def show
    prepare_morning
  end

  # Shows the complete kept trees resident on today's Daily Log.
  def evening
    @daily_roots = user_entries.daily_log(@today).to_a
    rendered_entries = @daily_roots.flat_map { |root| kept_resident_tree(root) }
    @done_task_count = rendered_entries.count { |entry| entry.kind == "task" && entry.state == "done" }
  end

  # Adds the existing priority signifier to one currently eligible Morning task.
  def mark_priority
    change_priority(:mark_priority!)
  end

  # Removes the existing priority signifier from one currently eligible Morning task.
  def clear_priority
    change_priority(:clear_priority!)
  end

  helper_method :morning_priority_eligible?, :evening_commands

  private

  def prepare_morning
    @source_groups = morning_source_groups
    @morning_priority_ids = @source_groups.flat_map do |group|
      group.fetch(:roots).flat_map { |root| kept_resident_tree(root) }
        .select { |entry| eligible_morning_task?(entry) }
        .map(&:id)
    end.to_set
  end

  def morning_source_groups
    month = @today.beginning_of_month
    groups = [
      source_group(
        "Monthly Calendar · #{@today.strftime('%B %Y')}",
        monthly_log_path(month: month.strftime("%Y-%m")),
        user_entries.monthly_calendar(month)
      ),
      source_group(
        "Monthly Tasks · #{@today.strftime('%B %Y')}",
        monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks"),
        user_entries.monthly_tasks(month)
      )
    ]
    (month..@today).each do |day|
      groups << source_group(
        "Daily Log · #{day.strftime('%B %-d, %Y')}",
        daily_log_path(date: day.iso8601),
        user_entries.daily_log(day)
      )
    end
    groups.compact
  end

  def source_group(label, path, roots)
    qualifying_roots = roots.select do |root|
      kept_resident_tree(root).any? { |entry| eligible_morning_task?(entry) }
    end
    return if qualifying_roots.empty?

    { label: label, path: path, roots: qualifying_roots }
  end

  def eligible_morning_task?(entry)
    entry.kind == "task" && entry.state == "open" && entry.successor.nil?
  end

  def morning_priority_eligible?(entry)
    @morning_priority_ids.include?(entry.id)
  end

  def evening_commands(entry)
    return [] if entry.successor
    return %w[complete strike schedule] if entry.kind == "task" && entry.state == "open"
    return %w[schedule] if entry.kind == "event"

    []
  end

  def set_priority_entry
    @priority_entry = user_entries.kept.find(params[:id])
  end

  def change_priority(command)
    prepare_morning
    raise Entry::LifecycleError unless morning_priority_eligible?(@priority_entry)

    @priority_entry.public_send(command)
    redirect_to reflection_path
  end

  def refuse_priority_change
    redirect_to reflection_path, alert: REFUSAL_ALERT
  end

  def render_priority_not_found
    head :not_found
  end
end
