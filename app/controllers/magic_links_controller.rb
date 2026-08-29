# Accepts enumeration-neutral requests for existing-account sign-in links.
class MagicLinksController < ApplicationController
  # One budget for known and unknown requests so lock + increment + enqueue
  # cannot name an account. 50ms sits above that extra work on this app's
  # SQLite Solid Queue path and stays inside the per-IP mail budget.
  REQUEST_DURATION_FLOOR = 0.05

  allow_unauthenticated_access
  before_action :protect_authentication_response
  rate_limit_outbound_authentication_mail only: :create, with: :redirect_to_sent

  # Advances a known account and queues only its integer identity and generation.
  def create
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    user = User.find_by(email_address: normalized_email_address)
    enqueue_magic_link(user) if user
    wait_for_request_floor(started_at)
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

  def wait_for_request_floor(started_at)
    remaining = REQUEST_DURATION_FLOOR - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at)
    sleep(remaining) if remaining.positive?
  end
end
