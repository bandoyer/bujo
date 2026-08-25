require "test_helper"
require "open3"
require "rbconfig"
require "sqlite3"
require Rails.root.join("db/migrate/20260825050000_add_page_residency_to_entries")

# Runs the irreversible migration against an isolated legacy schema so its
# recursive tree backfill is exercised without mutating the test database.
class PageResidencyMigrationTest < ActiveSupport::TestCase
  test "backfills each tree from its root and leaves no placement default" do
    database_path = Rails.root.join("tmp/page_residency_migration_#{Process.pid}.sqlite3")
    FileUtils.rm_f(database_path)
    build_legacy_database(database_path)

    migration_path = Rails.root.join("db/migrate/20260825050000_add_page_residency_to_entries")
    script = <<~RUBY
      require "active_record"
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV.fetch(0))
      require ARGV.fetch(1)
      AddPageResidencyToEntries.new.migrate(:up)
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-e",
      script,
      database_path.to_s,
      migration_path.to_s
    )
    assert status.success?, [ stdout, stderr ].join("\n")

    database = SQLite3::Database.new(database_path.to_s)
    database.results_as_hash = true
    rows = database.execute(
      "SELECT id, page_kind, page_on, collection_id FROM entries ORDER BY id"
    )
    assert_equal [
      { "id" => "collection-child", "page_kind" => "collection", "page_on" => nil, "collection_id" => "camping" },
      { "id" => "collection-root", "page_kind" => "collection", "page_on" => nil, "collection_id" => "camping" },
      { "id" => "daily-child", "page_kind" => "daily", "page_on" => "2026-08-24", "collection_id" => nil },
      { "id" => "daily-root", "page_kind" => "daily", "page_on" => "2026-08-24", "collection_id" => nil }
    ], rows.map { |row| row.slice("id", "page_kind", "page_on", "collection_id") }

    columns = database.execute("PRAGMA table_info(entries)").index_by { |column| column.fetch("name") }
    assert_equal 1, columns.fetch("page_kind").fetch("notnull")
    assert_nil columns.fetch("page_kind").fetch("dflt_value")
    assert_equal 0, columns.fetch("page_on").fetch("notnull")
  ensure
    database&.close
    FileUtils.rm_f(database_path) if database_path
  end

  test "declares rollback irreversible before touching data" do
    error = assert_raises(ActiveRecord::IrreversibleMigration) do
      AddPageResidencyToEntries.new.down
    end

    assert_match(/cannot be converted back/, error.message)
  end

  private

  def build_legacy_database(database_path)
    database = SQLite3::Database.new(database_path.to_s)
    database.execute_batch <<~SQL
      CREATE TABLE entries (
        id varchar PRIMARY KEY,
        user_id integer NOT NULL,
        logged_on date NOT NULL,
        collection_id varchar,
        parent_id varchar
      );
      CREATE INDEX index_entries_on_user_id_and_logged_on ON entries(user_id, logged_on);
      INSERT INTO entries VALUES ('daily-root', 1, '2026-08-24', NULL, NULL);
      INSERT INTO entries VALUES ('daily-child', 1, '2030-01-01', 'wrong', 'daily-root');
      INSERT INTO entries VALUES ('collection-root', 1, '2026-08-20', 'camping', NULL);
      INSERT INTO entries VALUES ('collection-child', 1, '2030-02-02', NULL, 'collection-root');
    SQL
  ensure
    database&.close
  end
end
