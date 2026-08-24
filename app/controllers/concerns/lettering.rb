# The reader's hand-lettering choice: its ordered labels and persisted value.
module Lettering
  extend ActiveSupport::Concern
  include PreferenceCookies

  HAND_OPTIONS = [
    [ "marker", "marker" ],
    [ "rock-salt", "rock salt" ],
    [ "architects-daughter", "architects" ],
    [ "patrick-hand", "patrick" ],
    [ "gochi-hand", "gochi" ],
    [ "serif", "serif" ]
  ].freeze
  STORED_HANDS = HAND_OPTIONS.drop(1).map(&:first).freeze

  included do
    helper_method :hand_preference, :hand_options
  end

  private

  # The stored hand, or nil when the reader uses the default marker face.
  def hand_preference
    stored_preference(:hand, STORED_HANDS)
  end

  # The explicit value/label pairs keep UI copy independent from cookie values.
  def hand_options
    HAND_OPTIONS
  end

  # Stores an explicit hand; marker and invalid values both restore the default.
  def store_hand_preference(hand)
    store_preference_cookie(:hand, hand, STORED_HANDS)
  end
end
