# The reader's color-theme choice: how it is read back and how it persists.
module Theming
  extend ActiveSupport::Concern

  # The themes a reader can choose outright; "system" is the absence of a choice.
  EXPLICIT_THEMES = %w[light dark].freeze

  included do
    helper_method :theme_preference
  end

  private

  # The stored choice, or nil when the reader left the theme to the system.
  def theme_preference
    cookies[:theme] if EXPLICIT_THEMES.include?(cookies[:theme])
  end

  # Stores an explicit choice; anything else, "system" included, clears it.
  def store_theme_preference(theme)
    if EXPLICIT_THEMES.include?(theme)
      cookies.permanent[:theme] = { value: theme, same_site: :lax }
    else
      cookies.delete(:theme)
    end
  end
end
