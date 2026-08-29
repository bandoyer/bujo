require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  class FailingQueueAdapter
    def enqueue(_job)
      raise ActiveJob::EnqueueError, "queue unavailable"
    end

    def enqueue_at(_job, _timestamp)
      raise ActiveJob::EnqueueError, "queue unavailable"
    end
  end

  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "requesting a link for a normalized known address advances once and queues safe arguments" do
    assert_changes -> { @user.reload.magic_link_version }, from: 0, to: 1 do
      assert_enqueued_with(job: MagicLinkDeliveryJob, args: [ @user.id, 1 ]) do
        post sign_in_link_path, params: { email_address: "  #{ @user.email_address.upcase } " }
      end
    end

    assert_redirected_to sent_sign_in_link_path
    assert_response :see_other
  end

  test "known unknown and blank requests have the same public acknowledgement" do
    responses = [ @user.email_address, "missing@example.com", "" ].map do |email_address|
      post sign_in_link_path, params: { email_address: email_address }
      [ response.status, response.location, flash.to_hash ]
    end

    assert_equal 1, responses.uniq.size
    assert_equal 1, @user.reload.magic_link_version
    assert_enqueued_jobs 1, only: MagicLinkDeliveryJob

    get sent_sign_in_link_path
    assert_response :success
    assert_select "h1", "Check your email"
    assert_includes response.body, "If that email belongs to an account, a sign-in link is on its way."
    assert_not_includes response.body, @user.email_address
  end

  test "enqueue failure leaves the newer generation committed and keeps public parity" do
    original_adapter = MagicLinkDeliveryJob.queue_adapter
    MagicLinkDeliveryJob.queue_adapter = FailingQueueAdapter.new

    assert_nothing_raised do
      post sign_in_link_path, params: { email_address: @user.email_address }
    end

    assert_equal 1, @user.reload.magic_link_version
    assert_redirected_to sent_sign_in_link_path
  ensure
    MagicLinkDeliveryJob.queue_adapter = original_adapter if original_adapter
  end

  test "per-address short budget is shared by known and unknown identities" do
    5.times { post sign_in_link_path, params: { email_address: @user.email_address } }

    assert_no_changes -> { @user.reload.magic_link_version } do
      assert_no_enqueued_jobs only: MagicLinkDeliveryJob do
        post sign_in_link_path, params: { email_address: @user.email_address.upcase }
      end
    end
    assert_redirected_to sent_sign_in_link_path
  end

  test "per-address daily budget returns the same acknowledgement without queueing" do
    identity = Authentication.email_rate_limit_identity(@user.email_address)
    Rails.cache.write(
      "rate-limit:#{Authentication::OUTBOUND_MAIL_RATE_LIMIT_SCOPE}:daily-email:#{identity}",
      20,
      expires_in: 24.hours
    )

    assert_no_changes -> { @user.reload.magic_link_version } do
      assert_no_enqueued_jobs only: MagicLinkDeliveryJob do
        post sign_in_link_path, params: { email_address: @user.email_address }
      end
    end
    assert_redirected_to sent_sign_in_link_path
  end

  test "per-IP budget cannot be bypassed by rotating addresses" do
    10.times do |attempt|
      post sign_in_link_path, params: { email_address: "missing-#{attempt}@example.com" }
    end

    assert_no_changes -> { @user.reload.magic_link_version } do
      post sign_in_link_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to sent_sign_in_link_path
  end

  test "email limit keys are keyed digests and never contain the address" do
    identity = Authentication.email_rate_limit_identity(@user.email_address)

    assert_match(/\A[0-9a-f]{64}\z/, identity)
    assert_not_includes identity, @user.email_address
    assert_not_equal Authentication.email_rate_limit_identity("other@example.com"), identity
  end
end
