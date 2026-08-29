# Stages scanner-safe landings and consumes credentials only on explicit POST.
class MagicLinkRedemptionsController < ApplicationController
  INVALID_LINK_ALERT = "That sign-in link is invalid or has expired."

  allow_unauthenticated_access
  before_action :protect_authentication_response

  rate_limit to: 20, within: 10.minutes, only: :create, with: :refuse_redemption

  # Renders an inert form without inspecting any candidate credential.
  def show
  end

  # Consumes one valid credential before starting the ordinary session path.
  def create
    user = User.consume_magic_link(params[:token])
    return refuse_redemption unless user

    start_new_session_for(user)
    redirect_to after_authentication_url
  end

  private

  def refuse_redemption
    redirect_to new_session_path, alert: INVALID_LINK_ALERT, status: :see_other
  end
end
