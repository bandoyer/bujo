require "test_helper"

class MagicLinksMailerTest < ActionMailer::TestCase
  test "sign-in message has the exact multipart sender recipient subject and copy" do
    user = users(:one)
    token = user.generate_token_for(:magic_link)
    mail = MagicLinksMailer.sign_in(user, token)

    assert_equal [ "Bujo <sign-in@bujo.blackcat.dev>" ], mail.from.map { |address| mail[:from].to_s }
    assert_equal [ user.email_address ], mail.to
    assert_equal "Your Bujo sign-in link", mail.subject
    assert_predicate mail, :multipart?
    assert_equal [ "text/plain", "text/html" ], mail.parts.map(&:mime_type)

    [ mail.text_part.decoded, mail.html_part.decoded ].each do |body|
      assert_includes body, "Open your journal"
      assert_includes body, "This link expires in 15 minutes and works once."
      assert_includes body, "If you requested more than one, use the newest email."
      assert_includes body, "If you did not request this, you can ignore this email."
    end
  end

  test "token appears only in a no-referrer fragment on the configured canonical origin" do
    token = users(:one).generate_token_for(:magic_link)
    mail = MagicLinksMailer.sign_in(users(:one), token)
    html = mail.html_part.decoded
    text = mail.text_part.decoded
    expected_url = "https://bujo.test/sign-in-link/open##{ERB::Util.url_encode(token)}"

    assert_includes html, %(href="#{expected_url}")
    assert_match(/<a [^>]*rel="noreferrer"[^>]*>/, html)
    assert_includes text, expected_url
    assert_no_match(%r{sign-in-link/open[?/][^#]*#{Regexp.escape(token)}}, html + text)
    assert_no_match(/<img|src=|https:\/\/fonts\.|unsubscribe/i, html + text)
  end

  test "password reset also uses the configured sender and canonical origin" do
    mail = PasswordsMailer.reset(users(:one))

    assert_equal "Bujo <sign-in@bujo.blackcat.dev>", mail[:from].to_s
    assert_match(%r{https://bujo\.test/passwords/}, mail.html_part.decoded)
  end
end
