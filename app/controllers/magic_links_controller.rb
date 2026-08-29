# Accepts enumeration-neutral requests for existing-account sign-in links.
class MagicLinksController < ApplicationController
  allow_unauthenticated_access
  before_action :protect_authentication_response
  rate_limit_outbound_authentication_mail only: :create, with: :redirect_to_sent

  # Advances a known account and queues only its integer identity and generation.
  def create
    user = User.find_by(email_address: normalized_email_address)
    enqueue_magic_link(user) if user
    redirect_to_sent
  end

  # Renders the same acknowledgement regardless of request outcome.
  def sent
  end

  private

  def enqueue_magic_link(user)
    generation = user.issue_magic_link!
    job = MagicLinkDeliveryJob.new(user.id, generation)
    return if job.enqueue

    report_enqueue_failure(
      job.enqueue_error || ActiveJob::EnqueueError.new("MagicLinkDeliveryJob was not enqueued")
    )
  end

  def report_enqueue_failure(error)
    Rails.error.report(error, handled: true, context: {
      job: "MagicLinkDeliveryJob",
      user_digest: Authentication.email_rate_limit_identity(normalized_email_address)
    })
  end

  def redirect_to_sent
    redirect_to sent_sign_in_link_path, status: :see_other
  end
end
