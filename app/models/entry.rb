# Represents one immutable-residency bullet and its append-only movement
# history within a user's journal.
class Entry < ApplicationRecord
  # Signals a lifecycle or movement command that the current entry cannot
  # perform without rewriting journal history.
  class LifecycleError < StandardError; end

  include UuidV7Id
  include SoftDeletable

  # Bullet kinds shared with the parser.
  KINDS = %w[task event note].freeze
  # Complete task lifecycle.
  TASK_STATES = %w[open done struck migrated].freeze
  # Every supported page residency.
  PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future collection].freeze
  # Bullet vocabulary admitted at each page root.
  ROOT_KINDS = {
    "daily" => KINDS,
    "monthly_calendar" => KINDS,
    "monthly_tasks" => KINDS,
    "future" => %w[task event],
    "collection" => KINDS
  }.freeze
  # Page kinds whose page_on must be a month boundary.
  MONTHLY_PAGE_KINDS = %w[monthly_calendar monthly_tasks].freeze
  # Time guards for directly writable pages.
  CAPTURE_ADMISSION_METHODS = {
    "daily" => :daily_capture_admitted?,
    "monthly_calendar" => :monthly_capture_admitted?,
    "monthly_tasks" => :monthly_capture_admitted?,
    "future" => :future_capture_admitted?
  }.freeze
  # Immutable residency tuple.
  PLACEMENT_ATTRIBUTES = %w[page_kind page_on collection_id].freeze
  # Canonical 24-hour time.
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
    -> { in_capture_order },
    class_name: "Entry",
    foreign_key: :parent_id,
    inverse_of: :parent
  has_one :successor,
    class_name: "Entry",
    foreign_key: :migrated_from_id,
    inverse_of: :predecessor

  # The UUIDv7 id breaks created_at ties in capture order rather than fighting
  # it, so rows written in the same instant still read back in capture order.
  scope :in_capture_order, -> { order(:created_at, :id) }
  # Orders dated residents by day, time, and stable capture identity.
  scope :in_calendar_order, -> {
    order(:occurs_on, arel_table[:time_of_day].asc.nulls_last, :created_at, :id)
  }
  # Returns root residents of one Daily Log.
  scope :daily_log, ->(date) {
    kept.where(page_kind: "daily", page_on: date, parent_id: nil).in_capture_order
  }
  # Returns root residents of one Monthly Calendar page.
  scope :monthly_calendar, ->(month) {
    kept.where(page_kind: "monthly_calendar", page_on: month.beginning_of_month, parent_id: nil)
      .in_calendar_order
  }
  # Returns root residents of one Monthly Tasks page.
  scope :monthly_tasks, ->(month) {
    kept.where(page_kind: "monthly_tasks", page_on: month.beginning_of_month, parent_id: nil)
      .in_capture_order
  }
  # Returns every Future Log root, including overdue residents.
  scope :future_log, -> {
    kept.where(page_kind: "future", parent_id: nil).in_calendar_order
  }
  # Returns root residents of one Custom Collection page.
  scope :collection_page, ->(collection_id) {
    kept.where(
      page_kind: "collection",
      collection_id: collection_id,
      parent_id: nil
    ).in_capture_order
  }
  # Returns every kept open task regardless of page.
  scope :open_tasks, -> {
    kept.where(kind: "task", state: "open").in_capture_order
  }

  validates :text, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :page_kind, inclusion: { in: PAGE_KINDS }
  validates :time_of_day, format: { with: TIME_PATTERN }, allow_nil: true
  validate :state_matches_kind
  validate :placement_shape
  validate :placement_matches_parent
  validate :collection_belongs_to_user
  validate :placement_is_immutable

  class << self
    # Parses a rapid-log line and creates one root resident on the explicitly
    # supplied page. The parser's +today+ and admission's +as_of+ are separate
    # inputs because a page date never stands in for the wall-clock boundary.
    def capture!(line, user:, today:, as_of:, page_kind:, page_on:, collection: nil, occurs_on: nil,
      default_kind: :task, admission_context: nil, target_month: nil)
      parsed = Bujo::RapidLog.parse(line, today: today, default_kind: default_kind)
      return unless parsed

      entry = new(
        user: user,
        collection: collection,
        kind: parsed.kind,
        state: parsed.state,
        text: parsed.text,
        priority: parsed.priority,
        tags: parsed.tags,
        page_kind: page_kind,
        page_on: page_on,
        occurs_on: occurs_on || parsed.date,
        time_of_day: parsed.time
      )
      enforce_capture_admission!(entry, as_of, admission_context, target_month)
      entry.save!
      entry
    end

    # Answers whether a page admits ordinary capture on the supplied date.
    # Reading screens ask this before offering a writing affordance, so the
    # control a reader sees and the guard the command enforces are one rule
    # rather than two that have to be kept in step by hand.
    def capture_admitted?(page_kind:, as_of:, page_on: nil, occurs_on: nil)
      admission_method = CAPTURE_ADMISSION_METHODS[page_kind]
      return true unless admission_method

      send(admission_method, page_on: page_on, occurs_on: occurs_on, as_of: as_of)
    end

    # Past, current, and the immediately next month may open as a ritual target;
    # anything later is refused. Screens and capture share this one horizon.
    def migration_target_admitted?(month, as_of:)
      !month.nil? && month.beginning_of_month <= as_of.next_month.beginning_of_month
    end

    private

    def enforce_capture_admission!(entry, as_of, admission_context, target_month)
      admitted = if admission_context == :monthly_migration
        monthly_migration_capture_admitted?(entry, as_of, target_month)
      else
        capture_admitted?(
          page_kind: entry.page_kind,
          page_on: entry.page_on,
          occurs_on: entry.occurs_on,
          as_of: as_of
        )
      end
      return if admitted

      entry.errors.add(:base, :invalid)
      raise ActiveRecord::RecordInvalid, entry
    end

    # Monthly setup deliberately opens only its URL-derived Tasks page. The
    # ordinary predicate above stays unchanged because normal Monthly screens
    # must remain closed for next month.
    def monthly_migration_capture_admitted?(entry, as_of, target_month)
      return false unless entry.page_kind == "monthly_tasks" && entry.kind == "task" && target_month

      canonical_target = target_month.beginning_of_month
      entry.page_on == canonical_target && migration_target_admitted?(canonical_target, as_of: as_of)
    end

    # Each admission rule names only the placement dates it judges and ignores
    # the rest, so the dispatch table can call them all the same way.
    def daily_capture_admitted?(page_on:, as_of:, **)
      !page_on.nil? && page_on <= as_of
    end

    def monthly_capture_admitted?(page_on:, as_of:, **)
      !page_on.nil? && page_on <= as_of.beginning_of_month
    end

    def future_capture_admitted?(occurs_on:, as_of:, **)
      !occurs_on.nil? && occurs_on > as_of.end_of_month
    end
  end

  # Marks this open task complete.
  def complete!
    transition_to!("done", from: "open")
  end

  # Strikes this open task without deleting its history.
  def strike!
    transition_to!("struck", from: "open")
  end

  # Reopens a completed or struck task.
  def reopen!
    transition_to!("open", from: %w[done struck])
  end

  # Appends one successor on a destination page. Tasks move only while open;
  # events and notes retain NULL state and become moved through their successor.
  def move_to!(page_kind:, page_on:, as_of:, collection: nil, occurs_on: nil)
    ensure_movable!
    ensure_future_destination!(page_kind, occurs_on, as_of)

    self.class.transaction do
      append_successor!(
        page_kind: page_kind,
        page_on: page_on,
        collection: collection,
        occurs_on: occurs_on,
        time_of_day: (time_of_day if occurs_on)
      )
    end
  end

  # Corrects the current live row without changing its residency, ownership,
  # tree position, movement links, or settled task lifecycle.
  def correct!(parsed, kind:)
    raise LifecycleError unless parsed && KINDS.include?(kind)

    with_lock do
      ensure_correctable!(kind)
      assign_attributes(correction_attributes(parsed, kind))
      save!
    end
  end

  # Answers whether correction may reinterpret this row's bullet kind. A live
  # movement end may fix its words, but its inherited kind records history.
  def kind_change_allowed?
    predecessor.nil? && successor.nil? && unresolved?
  end

  # Answers whether this row is still open work: an open task, or an event/note
  # whose state remains exact NULL.
  def unresolved?
    kind == "task" ? state == "open" : state.nil?
  end

  # Answers whether this row is the live successor of +source+ in a still-open
  # movement chain.
  def current_successor_of?(source)
    predecessor == source && source.successor == self && successor.nil?
  end

  # Renders correction's glyph-free rapid-log line in canonical metadata
  # order, so reparsing does not depend on the request date.
  def canonical_edit_line
    [
      ("*" if priority?),
      text,
      *tags.map { |tag| "+#{tag}" },
      occurs_on,
      time_of_day
    ].compact.join(" ")
  end

  # Appends a compensating successor at an earlier row's exact residency. It
  # intentionally bypasses ordinary Future admission because restoration may
  # occur after that persisted date has become current or overdue.
  def compensate_to!(source)
    self.class.transaction do
      source.lock!
      lock!
      ensure_compensatable!(source)

      append_successor!(
        page_kind: source.page_kind,
        page_on: source.page_on,
        collection: source.collection,
        occurs_on: source.occurs_on,
        time_of_day: source.time_of_day
      )
    end
  rescue ActiveRecord::RecordNotUnique
    raise LifecycleError
  end

  # Counts predecessors in this entry's visible movement chain.
  def carried_count
    count = 0
    entry = predecessor

    while entry
      count += 1
      entry = entry.predecessor
    end

    count
  end

  # Returns the journal glyph implied by kind, state, and successor residency.
  def glyph
    return moved_glyph if successor
    return "○" if kind == "event"
    return "–" if kind == "note"
    return "x" if state == "done"

    "•"
  end

  private

  def ensure_correctable!(requested_kind)
    raise LifecycleError unless kept? && successor.nil?
    raise LifecycleError unless ROOT_KINDS.fetch(page_kind, []).include?(requested_kind)
    raise LifecycleError if requested_kind != kind && !kind_change_allowed?
  end

  def correction_attributes(parsed, requested_kind)
    {
      kind: requested_kind,
      state: corrected_state(requested_kind),
      text: parsed.text,
      priority: parsed.priority,
      tags: parsed.tags,
      occurs_on: parsed.date,
      time_of_day: parsed.time
    }
  end

  def corrected_state(requested_kind)
    return state if requested_kind == kind

    requested_kind == "task" ? "open" : nil
  end

  def ensure_compensatable!(source)
    reload
    source.reload
    raise LifecycleError unless kept_chain_members?(source)
    raise LifecycleError unless current_successor_of?(source)
    raise LifecycleError unless unresolved?
    raise LifecycleError unless source_collection_kept?(source)
  end

  def kept_chain_members?(source)
    kept? && source.kept? && user == source.user
  end

  def source_collection_kept?(source)
    source.collection.nil? || source.collection.kept?
  end

  # One successor-append for ordinary movement and compensating Undo.
  def append_successor!(attributes)
    moved_entry = self.class.new(
      successor_attributes.merge(attributes).merge(predecessor: self)
    )
    raise LifecycleError unless moved_entry.valid?

    moved_entry.save!
    update!(state: "migrated") if kind == "task"
    moved_entry
  end

  def state_matches_kind
    if kind == "task"
      errors.add(:state, :inclusion) unless TASK_STATES.include?(state)
    elsif KINDS.include?(kind) && !state.nil?
      errors.add(:state, :invalid)
    end
  end

  # Placement shape is checked on every entry; the root-only rules follow,
  # since a child inherits its root's placement rather than choosing one.
  def placement_shape
    validate_page_on
    validate_collection_presence
    return if parent

    validate_root_kind
    validate_required_occurrence
  end

  def validate_page_on
    valid = case page_kind
    when "daily"
      page_on.present?
    when *MONTHLY_PAGE_KINDS
      page_on.present? && page_on == page_on.beginning_of_month
    when "future", "collection"
      page_on.nil?
    else
      true
    end
    errors.add(:page_on, :invalid) unless valid
  end

  def validate_collection_presence
    valid = page_kind == "collection" ? collection.present? : collection.nil?
    errors.add(:collection, :invalid) unless valid
  end

  def validate_root_kind
    allowed_kinds = ROOT_KINDS.fetch(page_kind, [])
    errors.add(:kind, :invalid) unless allowed_kinds.include?(kind)
  end

  def validate_required_occurrence
    case page_kind
    when "monthly_calendar"
      errors.add(:occurs_on, :invalid) unless occurs_on && page_on&.all_month&.cover?(occurs_on)
    when "future"
      errors.add(:occurs_on, :blank) unless occurs_on
    end
  end

  def placement_matches_parent
    return unless parent

    errors.add(:parent, :invalid) if parent == self || parent.user != user
    PLACEMENT_ATTRIBUTES.each do |attribute|
      errors.add(attribute, :invalid) unless public_send(attribute) == parent.public_send(attribute)
    end
  end

  def collection_belongs_to_user
    errors.add(:collection, :invalid) if collection && collection.user != user
  end

  def placement_is_immutable
    return unless persisted?

    PLACEMENT_ATTRIBUTES.each do |attribute|
      errors.add(attribute, :readonly) if will_save_change_to_attribute?(attribute)
    end
  end

  def transition_to!(new_state, from:)
    ensure_transition_from!(from)
    update!(state: new_state)
  end

  def ensure_movable!
    raise LifecycleError unless unresolved? && successor.nil?
  end

  def ensure_future_destination!(destination_kind, destination_date, as_of)
    return unless destination_kind == "future"
    return if destination_date && destination_date > as_of.end_of_month

    raise LifecycleError
  end

  def successor_attributes
    {
      user: user,
      kind: kind,
      state: ("open" if kind == "task"),
      text: text,
      priority: priority,
      tags: tags.dup,
      parent: nil
    }
  end

  def ensure_transition_from!(states)
    return if kind == "task" && Array(states).include?(state)

    raise LifecycleError
  end

  def moved_glyph
    successor.page_kind == "future" ? "<" : ">"
  end
end
