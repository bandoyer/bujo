require "test_helper"

# Verifies that a Collection row exposes only commands admitted by both its
# persisted residency and Entry's lifecycle, with the same rules behind
# crafted requests when no control is rendered.
class CollectionEntryCommandsControllerTest < ActionDispatch::IntegrationTest
  COMMANDS = %w[complete reopen strike migrate schedule move_to_collection].freeze

  setup do
    @user = users(:one)
    @collection = @user.collections.create!(name: "Rendered Commands")
    @foreign_collection = users(:two).collections.create!(name: "Crafted Foreign Topic")
    sign_in_as @user
  end

  test "Collection rows render the complete lifecycle and residency matrix" do
    collection_rows.each do |entry, expected_commands|
      get collection_path(@collection)
      assert_response :success
      assert_rendered_commands(entry, expected_commands)
    end
  end

  test "every absent Collection control is refused when crafted" do
    collection_rows.each do |entry, rendered_commands|
      (COMMANDS - rendered_commands).each do |command|
        original_journal = journal_snapshot

        assert_no_difference -> { Entry.count } do
          post public_send("#{command}_entry_path", entry), params: crafted_params(command)
        rescue NoMethodError => error
          flunk "#{command} must be refused on a Collection resident before the action body runs; it dereferenced nil (#{error.message})"
        end

        assert_redirected_to collection_path(@collection)
        assert_equal "That entry can't do that.", flash[:alert]
        assert_equal original_journal, journal_snapshot
        assert_nil entry.reload.successor unless entry.successor
      end
    end
  end

  private

  def collection_rows
    @collection_rows ||= [
      [ create_collection_entry("open task", kind: "task", state: "open"), %w[complete strike] ],
      [ create_collection_entry("done task", kind: "task", state: "done"), %w[reopen] ],
      [ create_collection_entry("struck task", kind: "task", state: "struck"), %w[reopen] ],
      [ create_collection_entry("migrated task", kind: "task", state: "migrated"), [] ],
      [ create_collection_entry("event", kind: "event", state: nil), [] ],
      [ moved_collection_entry("moved event", kind: "event"), [] ],
      [ create_collection_entry("note", kind: "note", state: nil), [] ],
      [ moved_collection_entry("moved note", kind: "note"), [] ]
    ]
  end

  def create_collection_entry(text, kind:, state:)
    @collection.entries.create!(
      user: @user, kind: kind, state: state, text: text, tags: [],
      page_kind: "collection", page_on: nil
    )
  end

  def moved_collection_entry(text, kind:)
    entry = create_collection_entry(text, kind: kind, state: nil)
    entry.move_to!(
      page_kind: "daily", page_on: Time.zone.today, as_of: Time.zone.today
    )
    entry
  end

  def assert_rendered_commands(entry, expected_commands)
    selector = "#entry_#{entry.id}"
    assert_select "#{selector} > .entry__toggle", count: expected_commands.any? ? 1 : 0
    assert_select "#{selector} > .entry__action-strip", count: expected_commands.any? ? 1 : 0

    COMMANDS.each do |command|
      expected_count = expected_commands.include?(command) ? 1 : 0
      assert_select "#{selector} form[action='#{public_send("#{command}_entry_path", entry)}']",
        count: expected_count
    end
  end

  def crafted_params(command)
    {
      viewed_on: "2035-11-20",
      return_to: "monthly_tasks",
      placement: "future",
      collection_id: @foreign_collection.id,
      topic: @foreign_collection.name,
      date: (Time.zone.today.next_month.beginning_of_month.iso8601 if command == "schedule")
    }.compact
  end

  def journal_snapshot
    @user.entries.order(:id).map(&:attributes)
  end
end
