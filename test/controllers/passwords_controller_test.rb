require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.take
    Rails.cache.clear
  end

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  test "update" do
    magic_token = @user.generate_token_for(:magic_link)

    assert_changes -> { [ @user.reload.password_digest, @user.magic_link_version ] },
      from: [ @user.password_digest, 0 ] do
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_session_path
    end

    assert_nil User.find_by_token_for(:magic_link, magic_token)
    follow_redirect!
    assert_notice "Password has been reset"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    magic_token = @user.generate_token_for(:magic_link)

    assert_no_changes -> { [ @user.reload.password_digest, @user.magic_link_version ] } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    assert_equal @user, User.find_by_token_for(:magic_link, magic_token)
    follow_redirect!
    assert_notice "Passwords did not match"
  end

  test "password reset uses the shared outbound-mail address budget" do
    Rails.cache.clear
    5.times { post passwords_path, params: { email_address: @user.email_address } }

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: @user.email_address.upcase }
    end

    assert_redirected_to new_password_path
  end

  test "password reset cannot bypass address capacity already used by magic links" do
    post sign_in_link_path, params: { email_address: @user.email_address }
    4.times { post passwords_path, params: { email_address: @user.email_address } }

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: @user.email_address }
    end

    assert_redirected_to new_password_path
  end

  test "password reset cannot bypass IP capacity already used by magic links" do
    10.times do |attempt|
      post sign_in_link_path, params: { email_address: "missing-#{attempt}@example.com" }
    end

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: @user.email_address }
    end

    assert_redirected_to new_password_path
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
