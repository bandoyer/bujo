require "test_helper"
require "open3"

class ProductionMailConfigurationTest < ActiveSupport::TestCase
  BOOT_ENV = {
    "RAILS_ENV" => "production",
    "SECRET_KEY_BASE_DUMMY" => "1",
    "RAILS_LOG_TO_STDOUT" => nil
  }.freeze

  test "production boots with the official Resend adapter and explicit canonical settings" do
    stdout, stderr, status = production_runner({
      "RESEND_API_KEY" => "re_test_key",
      "APP_ORIGIN" => "https://bujo.blackcat.dev",
      "MAIL_FROM" => "Bujo <sign-in@bujo.blackcat.dev>"
    }, <<~'RUBY')
      puts [
        ActionMailer::Base.delivery_method,
        ActionMailer::Base.raise_delivery_errors,
        ActionMailer::Base.perform_deliveries,
        Rails.application.config.action_mailer.default_url_options,
        Rails.application.config.x.mail_from,
        Rails.application.config.session_options.slice(:secure, :httponly, :same_site),
        Resend.api_key == "re_test_key"
      ].inspect
    RUBY

    assert status.success?, stderr
    assert_includes stdout, ":resend"
    assert_includes stdout, "bujo.blackcat.dev"
    assert_includes stdout, "secure: true"
    assert_includes stdout, "httponly: true"
    assert_includes stdout, "same_site: :lax"
    assert_includes stdout, "true"
  end

  test "production refuses missing secrets and malformed or unsafe origins" do
    configurations = [
      { "RESEND_API_KEY" => nil, "APP_ORIGIN" => "https://bujo.blackcat.dev", "MAIL_FROM" => approved_sender },
      { "RESEND_API_KEY" => "key", "APP_ORIGIN" => nil, "MAIL_FROM" => approved_sender },
      { "RESEND_API_KEY" => "key", "APP_ORIGIN" => "http://bujo.blackcat.dev", "MAIL_FROM" => approved_sender },
      { "RESEND_API_KEY" => "key", "APP_ORIGIN" => "https://bujo.questlog.dev", "MAIL_FROM" => approved_sender },
      { "RESEND_API_KEY" => "key", "APP_ORIGIN" => "https://user@bujo.blackcat.dev/path?query=yes#fragment", "MAIL_FROM" => approved_sender },
      { "RESEND_API_KEY" => "key", "APP_ORIGIN" => "https://bujo.blackcat.dev", "MAIL_FROM" => nil }
    ]

    configurations.each do |configuration|
      _stdout, _stderr, status = production_runner(configuration, "puts :booted")
      assert_not status.success?, "unsafe production mail configuration booted"
    end
  end

  private

  def approved_sender
    "Bujo <sign-in@bujo.blackcat.dev>"
  end

  def production_runner(environment, script)
    Open3.capture3(BOOT_ENV.merge(environment), "bin/rails", "runner", script,
      chdir: Rails.root.to_s)
  end
end
