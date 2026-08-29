require "openssl"

module Authentication
  extend ActiveSupport::Concern

  # One cache scope prevents switching mail methods from bypassing quotas.
  OUTBOUND_MAIL_RATE_LIMIT_SCOPE = "outbound-authentication-mail"

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    # Shared per-IP and per-address budgets for magic-link and password-reset mail.
    def rate_limit_outbound_authentication_mail(only:, with:)
      rate_limit to: 10, within: 3.minutes, name: "ip",
        scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: only, with: with
      rate_limit to: 5, within: 15.minutes, name: "short-email",
        scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: only,
        by: -> { Authentication.email_rate_limit_identity(params[:email_address]) },
        with: with
      rate_limit to: 20, within: 24.hours, name: "daily-email",
        scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: only,
        by: -> { Authentication.email_rate_limit_identity(params[:email_address]) },
        with: with
    end
  end

  # Keyed digest for per-address mail budgets; never use the raw address as a cache key.
  def self.email_rate_limit_identity(email_address)
    normalized = User.normalize_value_for(:email_address, email_address.to_s)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, normalized)
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path
    end

    def after_authentication_url
      safe_internal_path(session.delete(:return_to_after_authenticating)) || root_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end

    # Scanner-safe auth pages are never stored, never leak through Referer, and
    # keep title-first hierarchy by suppressing the journal layout flash.
    def protect_authentication_response
      response.set_header("Cache-Control", "no-store")
      response.set_header("Referrer-Policy", "no-referrer")
      @defer_layout_flash = true
    end

    def normalized_email_address
      User.normalize_value_for(:email_address, params[:email_address].to_s)
    end

    def safe_internal_path(candidate)
      candidate if candidate&.start_with?("/") && !candidate.start_with?("//")
    end
end
