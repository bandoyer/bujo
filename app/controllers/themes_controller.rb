# Persists the user's explicit color-theme preference in a cookie.
class ThemesController < ApplicationController
  # Sets light or dark explicitly; system removes the override.
  def update
    if THEME_PREFERENCES.include?(params[:theme])
      cookies.permanent[:theme] = { value: params[:theme], same_site: :lax }
    else
      cookies.delete(:theme)
    end

    redirect_back fallback_location: root_path
  end
end
