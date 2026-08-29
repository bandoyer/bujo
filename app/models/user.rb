class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :entries
  has_many :collections

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :magic_link, expires_in: 15.minutes do
    magic_link_version
  end

  # Advances the generation that a delivery job must match before sending.
  def issue_magic_link!
    with_lock do
      increment!(:magic_link_version)
      magic_link_version
    end
  end

  # Commits a new password and invalidates outstanding magic links together.
  def reset_password(attributes)
    with_lock do
      assign_attributes(attributes)
      self.magic_link_version += 1
      save
    end
  end

  # Consumes a valid bearer while serializing competing redemption attempts.
  def self.consume_magic_link(token)
    return if token.blank?

    candidate = find_by_token_for(:magic_link, token)
    return unless candidate

    candidate.with_lock do
      locked_candidate = find_by_token_for(:magic_link, token)
      return unless locked_candidate&.id == candidate.id

      candidate.increment!(:magic_link_version)
      candidate
    end
  end
end
