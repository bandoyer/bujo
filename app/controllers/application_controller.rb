class ApplicationController < ActionController::Base
  # The themes a reader can choose outright; "system" is the absence of a choice.
  EXPLICIT_THEMES = %w[light dark].freeze

  include Authentication
  helper_method :theme_preference
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def theme_preference
    cookies[:theme] if EXPLICIT_THEMES.include?(cookies[:theme])
  end
end
