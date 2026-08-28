# Represents a reader-named Custom Collection, which always belongs to its
# owner's Index while it is live.
class Collection < ApplicationRecord
  # Signals that guarded deletion is unavailable from the persisted state.
  class LifecycleError < StandardError; end

  include UuidV7Id
  include SoftDeletable

  # A concurrent insertion can take the candidate append rank. Retrying this
  # many times keeps that storage race bounded and turns exhaustion into an
  # ordinary invalid result.
  CREATION_ATTEMPTS = 3

  belongs_to :user
  has_many :entries

  before_validation :normalize_topic

  # Returns every kept Topic in permanent server-allocated append order.
  scope :in_index_order, -> { kept.order(:index_position, :id) }
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
    uniqueness: { scope: :user_id, conditions: -> { kept } },
    allow_nil: true
  validates :index_position, presence: true, if: :kept?
  validate :index_position_is_domain_owned

  class << self
    # Creates one live Collection at its owner's next permanent Index position.
    # Invalid Topic input returns the rejected record with its validation errors.
    def create_for(user:, topic:, id: nil)
      CREATION_ATTEMPTS.times do
        collection = attempt_create_for(user: user, topic: topic, id: id)
        return collection if collection
      end

      refused_create(user: user, topic: topic, id: id)
    end

    private

    # One attempt: persist at the next retained rank, return a validation
    # refusal, or return nil so the caller can retry a uniqueness race.
    def attempt_create_for(user:, topic:, id:)
      collection = new(user: user, name: topic, id: id)
      transaction(requires_new: true) do
        # send keeps rank allocation off the public API; only this path writes it.
        collection.send(:save_at_index_position!, next_index_position_for(user))
      end
      collection
    rescue ActiveRecord::RecordInvalid => error
      error.record
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    # Soft-deleted rows count too, so a tombstone's retained rank is never reused.
    def next_index_position_for(user)
      where(user: user).maximum(:index_position).to_i + 1
    end

    def refused_create(user:, topic:, id:)
      new(user: user, name: topic, id: id).tap do |collection|
        collection.errors.add(:base, "Collection could not be created")
      end
    end
  end

  # Answers whether the Collection has never held an entry and can therefore
  # be tombstoned without stranding journal history.
  def deletable?
    kept? && !entries.exists?
  end

  # Soft-deletes a kept, never-used Collection while retaining its Index rank.
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
    return if @allocating_index_position

    errors.add(:index_position, :readonly)
  end

  def save_at_index_position!(position)
    @allocating_index_position = true
    self.index_position = position
    save!
  ensure
    @allocating_index_position = false
  end
end
