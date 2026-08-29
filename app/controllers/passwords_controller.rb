class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  before_action :prevent_authentication_caching
  before_action :prevent_authentication_referrers
  rate_limit to: 10, within: 3.minutes, name: "ip",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    with: -> { redirect_to new_password_path, alert: "Try again later." }
  rate_limit to: 5, within: 15.minutes, name: "short-email",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    by: -> { MagicLinksController.email_rate_limit_identity(params[:email_address]) },
    with: -> { redirect_to new_password_path, alert: "Try again later." }
  rate_limit to: 20, within: 24.hours, name: "daily-email",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    by: -> { MagicLinksController.email_rate_limit_identity(params[:email_address]) },
    with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    normalized_email = User.normalize_value_for(:email_address, params[:email_address].to_s)
    if user = User.find_by(email_address: normalized_email)
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.reset_password(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
