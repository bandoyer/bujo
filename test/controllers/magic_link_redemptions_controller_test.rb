require "test_helper"
require "uri"

class MagicLinkRedemptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    Rails.cache.clear
  end

  test "fragmentless GET is inert no-store landing with a disabled blank form" do
    assert_no_changes -> { [ @user.reload.magic_link_version, @user.sessions.count ] } do
      get open_sign_in_link_path
    end

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
    assert_select "form[action='#{open_sign_in_link_path}'][method='post']" do
      assert_select "input[type='hidden'][name='token'][value='']", 1
      assert_select "button[disabled]", "Open your journal"
    end
    assert_select "[role='alert']", count: 0
  end

  test "valid POST consumes the token and creates the ordinary session once" do
    token = @user.generate_token_for(:magic_link)

    assert_difference -> { @user.sessions.count }, 1 do
      post open_sign_in_link_path, params: { token: token }
    end

    assert_equal 1, @user.reload.magic_link_version
    assert_redirected_to root_path
    assert cookies[:session_id]

    assert_no_difference -> { @user.sessions.count } do
      post open_sign_in_link_path, params: { token: token }
    end
    assert_redirected_to new_session_path
  end

  test "blank malformed expired superseded and reused tokens share one refusal" do
    issued_at = Time.zone.local(2026, 8, 29, 9)
    expired = travel_to(issued_at) { @user.generate_token_for(:magic_link) }
    travel_to(issued_at + 15.minutes) do
      assert_refused expired
    end

    superseded = @user.generate_token_for(:magic_link)
    @user.issue_magic_link!
    assert_refused superseded

    current = @user.generate_token_for(:magic_link)
    assert_equal @user, User.consume_magic_link(current)

    [ nil, "", "malformed", current ].each { |token| assert_refused token }
  end

  test "already signed-in redemption replaces its cookie and preserves the other session" do
    existing_session = @user.sessions.create!
    sign_in_as(@user)
    existing_cookie = cookies[:session_id]
    token = @user.generate_token_for(:magic_link)

    assert_difference -> { @user.sessions.count }, 1 do
      post open_sign_in_link_path, params: { token: token }
    end

    assert_not_equal existing_cookie, cookies[:session_id]
    assert Session.exists?(existing_session.id)
  end

  test "success returns only to the protected internal path saved by the server" do
    get daily_log_path(date: "2026-08-29", return_to: "https://attacker.example/path")
    assert_redirected_to new_session_path

    post open_sign_in_link_path, params: {
      token: @user.generate_token_for(:magic_link),
      return_to: "https://attacker.example/path"
    }

    assert_redirected_to daily_log_path(date: "2026-08-29", return_to: "https://attacker.example/path")
    destination = URI.parse(response.location)
    assert_equal "www.example.com", destination.host
    assert_equal "/daily/2026-08-29", destination.path
  end

  test "redemption IP limit refuses without consuming a valid token" do
    20.times { post open_sign_in_link_path, params: { token: "malformed" } }
    token = @user.generate_token_for(:magic_link)

    assert_no_changes -> { [ @user.reload.magic_link_version, @user.sessions.count ] } do
      post open_sign_in_link_path, params: { token: token }
    end

    assert_redirected_to new_session_path
    assert_equal @user, User.find_by_token_for(:magic_link, token)
  end

  private

  def assert_refused(token)
    assert_no_difference -> { @user.sessions.count } do
      post open_sign_in_link_path, params: { token: token }
    end
    assert_redirected_to new_session_path

    follow_redirect!
    assert_select "[role='alert']", "That sign-in link is invalid or has expired."
    assert_select "form[action='#{sign_in_link_path}']"
  end
end
