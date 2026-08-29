class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  before_action :protect_authentication_response
  rate_limit_outbound_authentication_mail only: :create, with: :redirect_limited_password_reset

  def new
  end

  def create
    user = User.find_by(email_address: normalized_email_address)
    PasswordsMailer.reset(user).deliver_later if user

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

    def redirect_limited_password_reset
      redirect_to new_password_path, alert: "Try again later."
    end
end
