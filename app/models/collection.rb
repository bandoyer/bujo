# Represents a reader-named Custom Collection and its deliberate Index
# registration state.
class Collection < ApplicationRecord
  # Signals that a requested registration, unindex, or deletion transition is
  # not available from the Collection's persisted state.
  class LifecycleError < StandardError; end

  include UuidV7Id
  include SoftDeletable

  # Two registrations racing for the same rank collide on the kept-position
  # unique index; the loser re-reads the greatest position and appends again,
  # so only a run of collisions this long is treated as a refusal.
  REGISTRATION_ATTEMPTS = 3

  belongs_to :user
  has_many :entries

  before_validation :normalize_topic

  # Returns kept, explicitly registered Topics in manual registration order.
  scope :in_index_order, -> {
    kept.where.not(index_position: nil).order(:index_position, :id)
  }
  # Narrows a caller-scoped relation to one case-insensitive exact Topic.
  scope :with_exact_topic, ->(topic) {
    where("LOWER(name) = LOWER(?)", topic.to_s.strip)
  }

  validates :name, presence: true,
    uniqueness: {
      scope: :user_id,
      case_sensitive: false,
      conditions: -> { kept }
    }
  validates :index_position,
    numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validates :index_position,
    uniqueness: { scope: :user_id, conditions: -> { kept } },
    allow_nil: true
  validate :index_position_is_domain_owned

  # Answers whether this Collection can be deliberately added to the Index.
  def registrable?
    kept? && index_position.nil? && entries.kept.exists?
  end

  # Appends this nonempty Collection to the user's manual Index order.
  def register!
    attempts = 0

    begin
      attempts += 1
      register_once!
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # A lost attempt leaves its rejected rank assigned in memory, and a record
      # carrying unsaved changes cannot be locked. Discard it so the next
      # attempt re-reads the winner's rank, and so a refusal reports the
      # position the row actually still holds.
      reload
      raise LifecycleError if attempts >= REGISTRATION_ATTEMPTS

      retry
    end
  end

  # Removes this kept Collection from the Index without changing its Topic or
  # residents.
  def unindex!
    with_lock do
      raise LifecycleError unless kept? && index_position.present?

      write_index_position!(nil)
    end
  end

  # Answers whether the Collection has never held an entry and can therefore
  # be tombstoned without stranding journal history.
  def deletable?
    kept? && !entries.exists?
  end

  # Soft-deletes a kept, never-used Collection while preserving every other
  # field for later synchronization.
  def soft_delete_if_unused!(at: Time.current)
    with_lock do
      raise LifecycleError unless deletable?

      soft_delete!(at: at)
    end
  end

  private

  def normalize_topic
    self.name = name.strip if name
  end

  def index_position_is_domain_owned
    return unless will_save_change_to_index_position?
    return if @writing_index_position

    errors.add(:index_position, :readonly)
  end

  def register_once!
    with_lock do
      raise LifecycleError unless registrable?

      write_index_position!(next_index_position)
    end
  end

  # Soft-deleted rows count too. A phase-2 pull can deliver a tombstone that
  # still carries the rank another device gave it, and no rank may be issued
  # twice; no gesture in this app can reach that state on its own.
  def next_index_position
    user.collections.maximum(:index_position).to_i + 1
  end

  def write_index_position!(position)
    @writing_index_position = true
    update!(index_position: position)
  ensure
    @writing_index_position = false
  end
end
