# The reader's hand-lettering choice: its ordered labels and persisted value.
module Lettering
  extend ActiveSupport::Concern
  include PreferenceCookies

  # Ordered value/label pairs. The labels are fixed copy, never derived from
  # the value: "architects-daughter" reads "architects", and humanizing it
  # would produce "Architects daughter" and break the browser tests, which
  # select by exact label.
  HAND_OPTIONS = [
    [ "marker", "marker" ],
    [ "rock-salt", "rock salt" ],
    [ "architects-daughter", "architects" ],
    [ "patrick-hand", "patrick" ],
    [ "gochi-hand", "gochi" ],
    [ "sans", "sans" ]
  ].freeze
  # As with themes, the default leads the cycle and is stored as no cookie.
  STORED_HANDS = HAND_OPTIONS.drop(1).map(&:first).freeze
  HAND_LABELS = HAND_OPTIONS.to_h.freeze

  included do
    helper_method :hand_preference, :current_hand, :hand_choices, :hand_label
  end

  private

  # The stored hand, or nil when the reader uses the default marker face.
  # The layout stamps data-hand from this, so the default must read as nil.
  def hand_preference
    stored_preference(:hand, STORED_HANDS)
  end

  # What the toggle shows: the stored hand, or the default when none is.
  def current_hand
    hand_preference || HAND_OPTIONS.first.first
  end

  def hand_choices
    HAND_LABELS.keys
  end

  # The reader-facing name for a hand, which is not its stored value.
  def hand_label(hand)
    HAND_LABELS.fetch(hand)
  end

  # Stores an explicit hand; marker and invalid values both restore the default.
  def store_hand_preference(hand)
    store_preference_cookie(:hand, hand, STORED_HANDS)
  end
end
