# Soft deletion without a default_scope, which the slice rules out as a known
# footgun: every query opts in through +kept+, so a scope that forgets it shows
# deleted rows loudly rather than hiding live ones silently.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(deleted_at: nil) }
  end

  # Answers whether this record is live. It is the row-level counterpart of the
  # +kept+ scope, so a guard and a query name the concept with the same word.
  def kept?
    deleted_at.nil?
  end

  # Marks the record deleted without removing its row, so its id survives for
  # the sync protocol and for children that keep their own lifecycle.
  def soft_delete!(at: Time.current)
    update!(deleted_at: at)
  end
end
