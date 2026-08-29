require "test_helper"

class ResendDeliveryTest < ActionMailer::TestCase
  setup do
    @original_delivery_method = MagicLinksMailer.delivery_method
    @original_api_key = Resend.api_key
    Resend.api_key = "re_test_only"
  end

  teardown do
    MagicLinksMailer.delivery_method = @original_delivery_method
    Resend.api_key = @original_api_key
  end

  test "official adapter crosses the provider edge exactly once" do
    requests = []
    MagicLinksMailer.delivery_method = :resend

    with_resend_edge(->(params, options:) {
      requests << [ params, options ]
      { id: "provider-message-id" }
    }) do
      MagicLinksMailer.sign_in(users(:one), "opaque-token").deliver_now!
    end

    assert_equal 1, requests.size
    params, options = requests.sole
    assert_equal "Bujo <sign-in@bujo.blackcat.dev>", params.fetch(:from)
    assert_equal [ users(:one).email_address ], params.fetch(:to)
    assert_equal "Your Bujo sign-in link", params.fetch(:subject)
    assert_empty options
  end

  test "provider failure escapes the official adapter" do
    MagicLinksMailer.delivery_method = :resend

    with_resend_edge(->(*) { raise IOError, "provider unavailable" }) do
      assert_raises(IOError) do
        MagicLinksMailer.sign_in(users(:one), "opaque-token").deliver_now!
      end
    end
  end

  test "test delivery never invokes Resend" do
    MagicLinksMailer.delivery_method = :test

    with_resend_edge(->(*) { flunk("test mail attempted a provider request") }) do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        MagicLinksMailer.sign_in(users(:one), "opaque-token").deliver_now!
      end
    end
  end

  private

  def with_resend_edge(replacement)
    singleton = Resend::Emails.singleton_class
    singleton.alias_method(:send_before_delivery_test, :send)
    singleton.define_method(:send, replacement)
    yield
  ensure
    singleton.alias_method(:send, :send_before_delivery_test)
    singleton.remove_method(:send_before_delivery_test)
  end
end
