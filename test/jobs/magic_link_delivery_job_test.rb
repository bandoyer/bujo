require "test_helper"

class MagicLinkDeliveryJobTest < ActiveJob::TestCase
  test "current generation delivers synchronously from a token minted at performance time" do
    user = users(:one)
    generation = user.issue_magic_link!

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      MagicLinkDeliveryJob.perform_now(user.id, generation)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ user.email_address ], mail.to
    assert_match(%r{https://bujo\.test/sign-in-link/open#[^\s<]+}, mail.text_part.decoded)
  end

  test "stale generation and missing user deliver nothing" do
    user = users(:one)
    generation = user.issue_magic_link!
    user.issue_magic_link!

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      MagicLinkDeliveryJob.perform_now(user.id, generation)
      MagicLinkDeliveryJob.perform_now(-1, generation)
    end
  end

  test "delivery failures escape visibly without an automatic retry" do
    user = users(:one)
    generation = user.issue_magic_link!
    failing_delivery = Class.new do
      def initialize(*)
      end

      def deliver!(_mail)
        raise IOError, "provider failure"
      end
    end
    MagicLinksMailer.add_delivery_method(:failing_test_delivery, failing_delivery)
    original_method = MagicLinksMailer.delivery_method
    MagicLinksMailer.delivery_method = :failing_test_delivery

    assert_raises(IOError) { MagicLinkDeliveryJob.perform_now(user.id, generation) }
  ensure
    MagicLinksMailer.delivery_method = original_method if original_method
  end
end
