require "test_helper"

# Pins every routed Entry command to the page where its persisted resident
# lives. Request parameters may choose an established reader return only for
# Daily and Monthly pages; they never grant a command.
class EntryCommandAuthorizationControllerTest < ActionDispatch::IntegrationTest
  COMMANDS = %w[complete reopen strike migrate schedule].freeze
  PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future collection].freeze
  ALLOWED_COMMANDS = {
    "daily" => COMMANDS,
    "monthly_calendar" => COMMANDS,
    "monthly_tasks" => COMMANDS,
    "future" => [],
    "collection" => %w[complete reopen strike]
  }.freeze

  setup do
    @user = users(:one)
    @collection = @user.collections.create!(name: "Command Matrix")
    @foreign_collection = users(:two).collections.create!(name: "Foreign Command Target")
    sign_in_as @user
  end

  test "the residency policy covers exactly every routed member command" do
    assert_equal COMMANDS.sort, member_entry_commands.sort
  end

  test "every command obeys every persisted page residency cell" do
    PAGE_KINDS.product(member_entry_commands).each do |page_kind, command|
      entry = create_command_task(command, page_kind)
      original_journal = journal_snapshot

      if command.in?(ALLOWED_COMMANDS.fetch(page_kind))
        assert_command_succeeds(command, entry)
      else
        assert_command_refused(command, entry, original_journal)
      end
    end
  end

  test "foreign missing and soft-deleted entries are 404 for every command" do
    member_entry_commands.each do |command|
      foreign = create_command_task(command, "daily", user: users(:two))
      deleted = create_command_task(command, "daily")
      deleted.soft_delete!(at: Time.zone.parse("2026-08-25 11:00:00"))

      [ [ foreign.id, foreign.text ], [ "missing-entry-id", "missing words" ], [ deleted.id, deleted.text ] ].each do |id, secret|
        original_journal = unscoped_journal_snapshot

        assert_no_difference -> { Entry.unscoped.count } do
          post_command(command, id, standard_params(command, "daily"))
        end

        assert_response :not_found
        assert_not_includes response.body, id
        assert_not_includes response.body, secret
        assert_equal original_journal, unscoped_journal_snapshot
      end
    end
  end

  test "an unavailable resident Collection renders the uniform missing state for every command" do
    member_entry_commands.each do |command|
      unavailable_collection_entries(command).each do |entry, unavailable_topic|
        original_journal = unscoped_journal_snapshot

        assert_no_difference -> { Entry.unscoped.count } do
          post_command(command, entry, malicious_collection_params(command))
        end

        assert_response :not_found
        assert_select "h1", text: "Collection not found"
        assert_not_includes response.body, entry.id
        assert_not_includes response.body, entry.text
        assert_not_includes response.body, unavailable_topic
        assert_equal original_journal, unscoped_journal_snapshot
      end
    end
  end

  private

  def member_entry_commands
    Rails.application.routes.routes.filter_map do |route|
      action = route.defaults[:action]
      action if route.defaults[:controller] == "entries" && action != "create"
    end.uniq
  end

  def create_command_task(command, page_kind, user: @user)
    placement = placement_for(page_kind, user)
    user.entries.create!(
      kind: "task",
      state: command == "reopen" ? "done" : "open",
      text: "#{user.id} #{page_kind} #{command} #{SecureRandom.hex(3)}",
      tags: [],
      **placement
    )
  end

  def placement_for(page_kind, user)
    month = Time.zone.today.beginning_of_month
    case page_kind
    when "daily"
      { page_kind: page_kind, page_on: Time.zone.today }
    when "monthly_calendar"
      { page_kind: page_kind, page_on: month, occurs_on: Time.zone.today }
    when "monthly_tasks"
      { page_kind: page_kind, page_on: month }
    when "future"
      { page_kind: page_kind, page_on: nil, occurs_on: month.next_month }
    when "collection"
      collection = user == @user ? @collection : @foreign_collection
      { page_kind: page_kind, page_on: nil, collection: collection }
    end
  end

  def assert_command_succeeds(command, entry)
    expected_destination = command_destination(entry)

    if command.in?(%w[migrate schedule])
      assert_difference -> { Entry.count }, 1 do
        post_command(command, entry, standard_params(command, entry.page_kind))
      end
      assert_equal "migrated", entry.reload.state
      assert_not_nil entry.successor
      assert_equal(command == "migrate" ? "monthly_tasks" : "future", entry.successor.page_kind)
    else
      assert_no_difference -> { Entry.count } do
        post_command(command, entry, standard_params(command, entry.page_kind))
      end
      expected_state = { "complete" => "done", "strike" => "struck", "reopen" => "open" }.fetch(command)
      assert_equal expected_state, entry.reload.state
      assert_nil entry.successor
    end

    assert_nil flash[:alert]
    assert_redirected_to expected_destination
  end

  def assert_command_refused(command, entry, original_journal)
    assert_no_difference -> { Entry.count } do
      post_command(command, entry, standard_params(command, entry.page_kind))
    end

    assert_equal "That entry can't do that.", flash[:alert],
      "#{command} must be refused for persisted #{entry.page_kind} residency"
    assert_redirected_to command_destination(entry)
    assert_equal original_journal, journal_snapshot
    assert_nil entry.reload.successor
    follow_redirect!
  end

  def post_command(command, entry_or_id, params)
    post public_send("#{command}_entry_path", entry_or_id), params: params
  end

  def standard_params(command, page_kind)
    params = case page_kind
    when "monthly_calendar"
      { viewed_on: Time.zone.today.beginning_of_month.iso8601, return_to: "monthly_calendar" }
    when "monthly_tasks"
      { viewed_on: Time.zone.today.beginning_of_month.iso8601, return_to: "monthly_tasks" }
    when "collection"
      malicious_collection_params(command)
    else
      { viewed_on: Time.zone.today.iso8601 }
    end
    params[:date] = Time.zone.today.next_month.beginning_of_month.iso8601 if command == "schedule"
    params
  end

  def malicious_collection_params(command)
    {
      viewed_on: "2035-11-20",
      return_to: "monthly_tasks",
      placement: "future",
      collection_id: @foreign_collection.id,
      topic: @foreign_collection.name,
      date: (Time.zone.today.next_month.beginning_of_month.iso8601 if command == "schedule")
    }.compact
  end

  def command_destination(entry)
    case entry.page_kind
    when "monthly_calendar"
      monthly_log_path(month: Time.zone.today.strftime("%Y-%m"))
    when "monthly_tasks"
      monthly_log_path(month: Time.zone.today.strftime("%Y-%m"), view: "tasks")
    when "collection"
      collection_path(@collection)
    else
      daily_log_path(date: Time.zone.today.iso8601)
    end
  end

  def unavailable_collection_entries(command)
    [
      unavailable_collection_entry(command, :foreign),
      unavailable_collection_entry(command, :missing),
      unavailable_collection_entry(command, :deleted)
    ]
  end

  def unavailable_collection_entry(command, condition)
    collection = @user.collections.create!(name: "Unavailable #{condition} #{command}")
    entry = create_collection_task(command, collection)

    case condition
    when :foreign
      entry.update_column(:collection_id, @foreign_collection.id)
      [ entry, @foreign_collection.name ]
    when :missing
      missing_id = "0198f3b9-0000-7000-8000-#{SecureRandom.hex(6)}"
      Entry.connection.disable_referential_integrity { entry.update_column(:collection_id, missing_id) }
      [ entry, collection.name ]
    when :deleted
      collection.update_column(:deleted_at, Time.zone.parse("2026-08-25 12:00:00"))
      [ entry, collection.name ]
    end
  end

  def create_collection_task(command, collection)
    collection.entries.create!(
      user: @user,
      kind: "task",
      state: command == "reopen" ? "done" : "open",
      text: "Unavailable #{command} #{SecureRandom.hex(3)}",
      tags: [],
      page_kind: "collection",
      page_on: nil
    )
  end

  def journal_snapshot
    @user.entries.order(:id).map(&:attributes)
  end

  def unscoped_journal_snapshot
    Entry.unscoped.order(:id).map(&:attributes)
  end
end
