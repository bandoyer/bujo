class Collection < ApplicationRecord
  include UuidV7Id

  belongs_to :user
  has_many :entries

  scope :kept, -> { where(deleted_at: nil) }

  validates :name, presence: true,
    uniqueness: {
      scope: :user_id,
      case_sensitive: false,
      conditions: -> { where(deleted_at: nil) }
    }

  def soft_delete!(at: Time.current)
    update!(deleted_at: at)
  end
end
