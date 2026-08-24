# The reader's color-theme choice: how it is read back and how it persists.
module Theming
  extend ActiveSupport::Concern
  include PreferenceCookies

  # The cycle the header toggle walks. The default leads it and is stored as
  # the absence of a cookie, so the rest are the themes a reader picks outright.
  THEME_CHOICES = %w[system light dark].freeze
  EXPLICIT_THEMES = THEME_CHOICES.drop(1).freeze

  included do
    helper_method :theme_preference, :current_theme, :theme_choices
  end

  private

  # The stored choice, or nil when the reader left the theme to the system.
  # The layout stamps data-theme from this, so the default must read as nil.
  def theme_preference
    stored_preference(:theme, EXPLICIT_THEMES)
  end

  # What the toggle shows: the stored choice, or the default when none is.
  def current_theme
    theme_preference || THEME_CHOICES.first
  end

  def theme_choices
    THEME_CHOICES
  end

  # Stores an explicit choice; anything else, "system" included, clears it.
  def store_theme_preference(theme)
    store_preference_cookie(:theme, theme, EXPLICIT_THEMES)
  end
end
