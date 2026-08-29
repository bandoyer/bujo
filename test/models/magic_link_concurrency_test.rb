require "test_helper"

# Proves the globally single-use credential boundary against separate DB connections.
class MagicLinkConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    Session.delete_all
    User.update_all(magic_link_version: 0)
  end

  test "two competing consumers admit exactly one" do
    user = users(:one)
    token = user.generate_token_for(:magic_link)
    gate = Queue.new

    consumers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          User.consume_magic_link(token)&.id
        end
      end
    end
    2.times { gate << true }

    assert_equal [ nil, user.id ], consumers.map(&:value).sort_by { |id| id || -1 }
    assert_equal 1, user.reload.magic_link_version
  end
end
