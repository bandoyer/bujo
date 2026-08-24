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
end
