class Collection < ApplicationRecord
  include UuidV7Id
  include SoftDeletable

  belongs_to :user
  has_many :entries

  validates :name, presence: true,
    uniqueness: {
      scope: :user_id,
      case_sensitive: false,
      conditions: -> { kept }
    }
end
