require "openssl"

# Accepts enumeration-neutral requests for existing-account sign-in links.
class MagicLinksController < ApplicationController
  allow_unauthenticated_access
  before_action :prevent_authentication_caching
  before_action :prevent_authentication_referrers

  rate_limit to: 10, within: 3.minutes, name: "ip",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    with: :redirect_to_sent
  rate_limit to: 5, within: 15.minutes, name: "short-email",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    by: -> { self.class.email_rate_limit_identity(params[:email_address]) },
    with: :redirect_to_sent
  rate_limit to: 20, within: 24.hours, name: "daily-email",
    scope: Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE, only: :create,
    by: -> { self.class.email_rate_limit_identity(params[:email_address]) },
    with: :redirect_to_sent

  # Advances a known account and queues only its integer identity and generation.
  def create
    user = User.find_by(email_address: normalized_email_address)
    enqueue_magic_link(user) if user
    redirect_to_sent
  end

  # Renders the same acknowledgement regardless of request outcome.
  def sent
  end

  # Produces a stable keyed identity without putting an address in cache keys.
  def self.email_rate_limit_identity(email_address)
    normalized = User.normalize_value_for(:email_address, email_address.to_s)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, normalized)
  end

  private

  def normalized_email_address
    User.normalize_value_for(:email_address, params[:email_address].to_s)
  end

  def enqueue_magic_link(user)
    generation = user.issue_magic_link!
    job = MagicLinkDeliveryJob.new(user.id, generation)
    return if job.enqueue

    error = job.enqueue_error || ActiveJob::EnqueueError.new("MagicLinkDeliveryJob was not enqueued")
    report_enqueue_failure(error)
  end

  def report_enqueue_failure(error)
    Rails.error.report(error, handled: true, context: {
      job: "MagicLinkDeliveryJob",
      user_digest: self.class.email_rate_limit_identity(normalized_email_address)
    })
  end

  def redirect_to_sent
    redirect_to sent_sign_in_link_path, status: :see_other
  end
end
