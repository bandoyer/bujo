# Renders the current reader's live Morning and Evening reference lenses and
# authorizes the one priority gesture introduced by Daily Reflection.
class DailyReflectionsController < ApplicationController
  include JournalReading

  # Evening narrows the shared lifecycle strip to Complete, Strike, and Schedule.
  EVENING_COMMANDS = %w[complete strike schedule].freeze

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
    @done_task_count = @daily_roots.flat_map { |root| kept_resident_tree(root) }
      .count { |entry| entry.kind == "task" && entry.state == "done" }
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
    @source_groups = []
    @morning_priority_ids = Set.new

    morning_pages.each do |label, path, roots|
      qualifying_roots, eligible_ids = qualifying_morning_group(roots)
      next if qualifying_roots.empty?

      @morning_priority_ids.merge(eligible_ids)
      @source_groups << { label: label, path: path, roots: qualifying_roots }
    end
  end

  def qualifying_morning_group(roots)
    eligible_ids = []
    qualifying_roots = roots.select do |root|
      ids = kept_resident_tree(root).filter_map { |entry| entry.id if eligible_morning_task?(entry) }
      next if ids.empty?

      eligible_ids.concat(ids)
      true
    end
    [ qualifying_roots, eligible_ids ]
  end

  def morning_pages
    month = @today.beginning_of_month
    month_stamp = @today.strftime("%B %Y")
    [
      [
        "Monthly Calendar · #{month_stamp}",
        monthly_log_path(month: month.strftime("%Y-%m")),
        user_entries.monthly_calendar(month)
      ],
      [
        "Monthly Tasks · #{month_stamp}",
        monthly_log_path(month: month.strftime("%Y-%m"), view: "tasks"),
        user_entries.monthly_tasks(month)
      ],
      *(month..@today).map do |day|
        [
          "Daily Log · #{day.strftime('%B %-d, %Y')}",
          daily_log_path(date: day.iso8601),
          user_entries.daily_log(day)
        ]
      end
    ]
  end

  def eligible_morning_task?(entry)
    entry.kind == "task" && entry.unresolved? && entry.successor.nil?
  end

  def morning_priority_eligible?(entry)
    @morning_priority_ids.include?(entry.id)
  end

  def evening_commands(entry)
    offered_entry_commands(entry) & EVENING_COMMANDS
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
