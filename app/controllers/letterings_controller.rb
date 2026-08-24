# Persists the reader's hand-lettering preference in a device-local cookie.
class LetteringsController < ApplicationController
  # Records the submitted hand, then returns the reader to their screen.
  def update
    store_hand_preference(params[:hand])
    redirect_back fallback_location: root_path
  end
end
