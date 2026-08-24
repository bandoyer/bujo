# The reader's color-theme choice: how it is read back and how it persists.
module Theming
  extend ActiveSupport::Concern
  include PreferenceCookies

  # The themes a reader can choose outright; "system" is the absence of a choice.
  EXPLICIT_THEMES = %w[light dark].freeze

  included do
    helper_method :theme_preference
  end

  private

  # The stored choice, or nil when the reader left the theme to the system.
  def theme_preference
    stored_preference(:theme, EXPLICIT_THEMES)
  end

  # Stores an explicit choice; anything else, "system" included, clears it.
  def store_theme_preference(theme)
    store_preference_cookie(:theme, theme, EXPLICIT_THEMES)
  end
end
