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

    def prevent_authentication_caching
      response.set_header("Cache-Control", "no-store")
    end

    def prevent_authentication_referrers
      response.set_header("Referrer-Policy", "no-referrer")
    end

    def safe_internal_path(candidate)
      candidate if candidate&.start_with?("/") && !candidate.start_with?("//")
    end
end
