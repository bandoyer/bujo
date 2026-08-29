require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "owns entries and collections" do
    user = users(:one)

    assert_includes user.entries, entries(:open_task)
    assert_includes user.collections, collections(:camping)
  end

  test "magic link generation has a nonnegative database default" do
    column = User.columns_hash.fetch("magic_link_version")
    checks = ActiveRecord::Base.connection.check_constraints(:users).map(&:name)

    assert_equal :integer, column.type
    assert_equal 0, column.default
    assert_not column.null
    assert_includes checks, "users_magic_link_version_nonnegative"

    assert_raises ActiveRecord::StatementInvalid do
      users(:one).update_column(:magic_link_version, -1)
    end
  end

  test "issuing a magic link advances its generation and invalidates an older token" do
    user = users(:one)
    first_generation = user.issue_magic_link!
    first_token = user.generate_token_for(:magic_link)

    second_generation = user.issue_magic_link!

    assert_equal first_generation + 1, second_generation
    assert_nil User.find_by_token_for(:magic_link, first_token)
  end

  test "magic link expires at the exact fifteen minute boundary" do
    user = users(:one)
    issued_at = Time.zone.local(2026, 8, 29, 9)
    token = travel_to(issued_at) { user.generate_token_for(:magic_link) }

    travel_to(issued_at + 14.minutes + 59.seconds) do
      assert_equal user, User.find_by_token_for(:magic_link, token)
    end
    travel_to(issued_at + 15.minutes) do
      assert_nil User.find_by_token_for(:magic_link, token)
    end
  end

  test "consuming a magic link succeeds once and advances its generation" do
    user = users(:one)
    token = user.generate_token_for(:magic_link)

    assert_equal user, User.consume_magic_link(token)
    assert_equal 1, user.reload.magic_link_version
    assert_nil User.consume_magic_link(token)
    assert_equal 1, user.reload.magic_link_version
  end

  test "malformed and blank magic links do not change either user" do
    versions = User.order(:id).pluck(:magic_link_version)

    assert_nil User.consume_magic_link("malformed")
    assert_nil User.consume_magic_link("")
    assert_nil User.consume_magic_link(nil)

    assert_equal versions, User.order(:id).pluck(:magic_link_version)
  end

  test "consuming one user's link does not alter the other user" do
    one = users(:one)
    two = users(:two)
    token = one.generate_token_for(:magic_link)
    two_token = two.generate_token_for(:magic_link)

    assert_equal one, User.consume_magic_link(token)
    assert_equal 1, one.reload.magic_link_version
    assert_equal 0, two.reload.magic_link_version
    assert_equal two, User.find_by_token_for(:magic_link, two_token)
  end
end
