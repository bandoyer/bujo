# Persists the user's explicit color-theme preference in a cookie.
class ThemesController < ApplicationController
  # Records the submitted preference, then returns the reader to their screen.
  def update
    store_theme_preference(params[:theme])
    redirect_back fallback_location: root_path
  end
end
