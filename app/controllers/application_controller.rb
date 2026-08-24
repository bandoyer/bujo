class ApplicationController < ActionController::Base
  # Explicit themes supported by the cookie-backed preference.
  THEME_PREFERENCES = %w[light dark].freeze

  include Authentication
  helper_method :theme_preference
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def date_or_today(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    Time.zone.today
  end

  def theme_preference
    cookies[:theme] if THEME_PREFERENCES.include?(cookies[:theme])
  end
end
