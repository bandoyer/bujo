class Entry < ApplicationRecord
  class LifecycleError < StandardError; end

  include UuidV7Id

  KINDS = %w[task event note].freeze
  TASK_STATES = %w[open done struck migrated].freeze
  TIME_PATTERN = /\A([01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :user
  belongs_to :collection, optional: true
  belongs_to :parent, class_name: "Entry", optional: true, inverse_of: :children
  belongs_to :predecessor,
    class_name: "Entry",
    foreign_key: :migrated_from_id,
    optional: true,
    inverse_of: :successor
  has_many :children,
    -> { order(:created_at, :id) },
    class_name: "Entry",
    foreign_key: :parent_id,
    inverse_of: :parent
  has_one :successor,
    class_name: "Entry",
    foreign_key: :migrated_from_id,
    inverse_of: :predecessor

  scope :kept, -> { where(deleted_at: nil) }
  scope :daily_log, ->(date) {
    kept.where(logged_on: date, parent_id: nil).order(:created_at, :id)
  }
  scope :monthly_calendar, ->(month) {
    kept.where(occurs_on: month.all_month)
      .order(:occurs_on, arel_table[:time_of_day].asc.nulls_last, :created_at, :id)
  }
  scope :monthly_tasks, ->(month) {
    kept.where(kind: "task", logged_on: month.all_month).order(:created_at, :id)
  }
  scope :future_log, ->(after:) {
    kept.where(arel_table[:occurs_on].gt(after))
      .order(:occurs_on, arel_table[:time_of_day].asc.nulls_last, :created_at, :id)
  }
  scope :open_tasks, -> {
    kept.where(kind: "task", state: "open").order(:created_at, :id)
  }

  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :time_of_day, format: { with: TIME_PATTERN }, allow_nil: true
  validate :state_matches_kind
  validate :parent_belongs_to_user

  class << self
    def capture!(line, user:, today:, default_kind: :task, collection: nil)
      parsed = Bujo::RapidLog.parse(line, today: today, default_kind: default_kind)
      return unless parsed

      create!(
        user: user,
        collection: collection,
        kind: parsed.kind,
        state: parsed.state,
        text: parsed.text,
        priority: parsed.priority,
        tags: parsed.tags,
        logged_on: today,
        occurs_on: parsed.date,
        time_of_day: parsed.time
      )
    end
  end

  def complete!
    transition_to!("done", from: "open")
  end

  def strike!
    transition_to!("struck", from: "open")
  end

  def reopen!
    transition_to!("open", from: %w[done struck])
  end

  def migrate_to!(logged_on:, collection: nil)
    migrate_with!(
      logged_on: logged_on,
      occurs_on: nil,
      time_of_day: nil,
      collection: collection
    )
  end

  def schedule_to!(occurs_on:)
    migrate_with!(
      logged_on: logged_on,
      occurs_on: occurs_on,
      time_of_day: time_of_day,
      collection: nil
    )
  end

  def carried_count
    count = 0
    entry = predecessor

    while entry
      count += 1
      entry = entry.predecessor
    end

    count
  end

  def glyph
    return "○" if kind == "event"
    return "–" if kind == "note"
    return "x" if state == "done"
    return successor&.occurs_on? ? "<" : ">" if state == "migrated"

    "•"
  end

  def soft_delete!(at: Time.current)
    update!(deleted_at: at)
  end

  private

  def state_matches_kind
    if kind == "task"
      errors.add(:state, :inclusion) unless TASK_STATES.include?(state)
    elsif KINDS.include?(kind) && state.present?
      errors.add(:state, :invalid)
    end
  end

  def parent_belongs_to_user
    return unless parent

    errors.add(:parent, :invalid) if parent == self || parent.user != user
  end

  def transition_to!(new_state, from:)
    ensure_transition_from!(*Array(from))
    update!(state: new_state)
  end

  def migrate_with!(attributes)
    ensure_transition_from!("open")

    self.class.transaction do
      successor = self.class.create!(successor_attributes.merge(attributes, predecessor: self))
      update!(state: "migrated")
      successor
    end
  end

  def successor_attributes
    {
      user: user,
      kind: kind,
      state: "open",
      text: text,
      priority: priority,
      tags: tags.dup,
      parent: nil
    }
  end

  def ensure_transition_from!(*states)
    return if kind == "task" && states.include?(state)

    raise LifecycleError
  end
end
