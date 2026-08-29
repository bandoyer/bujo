require "test_helper"
require "timeout"

class CoreNotationHierarchyConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  TODAY = Date.new(2026, 8, 28)

  setup do
    Entry.delete_all
    @user = users(:one)
  end

  teardown do
    Entry.delete_all
  end

  test "settling a child before master completion admits both commands" do
    master = create_entry(text: "Master")
    child = create_entry(text: "Child", parent: master)

    results = force_first(-> { command_result(Entry.find(child.id), :complete!) }) do
      command_result(master, :complete!)
    end

    assert_equal [ :success, :success ], results
    assert_equal %w[done done], [ master.reload.state, child.reload.state ]
  end

  test "master completion check before settling an open child refuses only the master" do
    master = create_entry(text: "Master")
    child = create_entry(text: "Child", parent: master)

    results = force_first(-> { command_result(Entry.find(master.id), :complete!) }) do
      command_result(child, :strike!)
    end

    assert_equal [ Entry::LifecycleError, :success ], results
    assert_equal %w[open struck], [ master.reload.state, child.reload.state ]
  end

  test "master completion before child reopen admits both commands without a lock timeout" do
    master = create_entry(text: "Master")
    child = create_entry(text: "Child", state: "done", parent: master)

    results = force_first(-> { command_result(Entry.find(master.id), :complete!) }) do
      command_result(child, :reopen!)
    end

    assert_equal [ :success, :success ], results
    assert_equal %w[done open], [ master.reload.state, child.reload.state ]
  end

  test "child reopen retries an actual SQLite writer timeout behind master completion" do
    master = create_entry(text: "Master")
    child = create_entry(text: "Child", state: "done", parent: master)
    master_written = Queue.new
    timeout_seen = Queue.new
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_event|
      error = _event.payload[:exception_object]
      timeout_seen << true if error.is_a?(ActiveRecord::StatementTimeout)
    end

    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Entry.transaction do
          Entry.find(master.id).complete!
          master_written << true
          Timeout.timeout(2) { timeout_seen.pop }
        end
      end
      :success
    end
    master_written.pop
    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.raw_connection.busy_handler_timeout = 20
        command_result(Entry.find(child.id), :reopen!)
      ensure
        connection.raw_connection.busy_handler_timeout = 5000
      end
    end

    assert_equal [ :success, :success ], [ joined_result(first), joined_result(second) ]
    assert_equal %w[done open], [ master.reload.state, child.reload.state ]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "child reopen before master completion makes completion refuse" do
    master = create_entry(text: "Master")
    child = create_entry(text: "Child", state: "done", parent: master)

    results = force_first(-> { command_result(Entry.find(child.id), :reopen!) }) do
      command_result(master, :complete!)
    end

    assert_equal [ :success, Entry::LifecycleError ], results
    assert_equal %w[open open], [ master.reload.state, child.reload.state ]
  end

  test "master completion before first-child capture refuses the capture" do
    master = create_entry(text: "Master")

    results = force_first(-> { command_result(Entry.find(master.id), :complete!) }) do
      capture_result(master)
    end

    assert_equal [ :success, Entry::LifecycleError ], results
    assert_equal "done", master.reload.state
    assert_empty Entry.where(parent_id: master.id)
  end

  test "first-child capture before master completion makes completion refuse" do
    master = create_entry(text: "Master")

    results = force_first(-> { capture_result(Entry.find(master.id)) }) do
      command_result(master, :complete!)
    end

    assert_equal [ :success, Entry::LifecycleError ], results
    assert_equal "open", master.reload.state
    child = Entry.where(parent_id: master.id).sole
    assert_uuid_v7 child.id
    assert_equal [ "open", @user.id, master.page_kind, master.page_on ],
      child.values_at(:state, :user_id, :page_kind, :page_on)
  end

  private

  def force_first(first_operation)
    first_finished = Queue.new
    release_first = Queue.new
    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Entry.transaction do
          result = first_operation.call
          first_finished << result
          release_first.pop
        end
      end
    end
    first_result = first_finished.pop
    second = Thread.new { ActiveRecord::Base.connection_pool.with_connection { yield } }
    release_first << true

    [ first_result, joined_result(first), joined_result(second) ].values_at(0, 2)
  end

  def joined_result(thread)
    thread.join(2) || flunk("command thread did not finish")
    thread.value
  end

  def command_result(entry, command)
    entry.public_send(command)
    :success
  rescue Entry::LifecycleError
    Entry::LifecycleError
  rescue ActiveRecord::StatementTimeout, ActiveRecord::LockWaitTimeout, SQLite3::BusyException => error
    error.class
  end

  def capture_result(master)
    Entry.capture_child!("Child", parent: master, user: @user, today: TODAY, as_of: TODAY)
    :success
  rescue Entry::LifecycleError
    Entry::LifecycleError
  rescue ActiveRecord::StatementTimeout, ActiveRecord::LockWaitTimeout, SQLite3::BusyException => error
    error.class
  end

  def create_entry(overrides = {})
    Entry.create!({
      user: @user, kind: "task", state: "open", text: "Task",
      priority: false, inspiration: false, tags: [], page_kind: "daily", page_on: TODAY
    }.merge(overrides))
  end
end
