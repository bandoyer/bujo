require "test_helper"
require "open3"
require "rbconfig"
require "sqlite3"

# Verifies the Collection Index schema transition against isolated copies of
# the pre-slice database so the proof never mutates the test database.
class CollectionIndexPositionMigrationTest < ActiveSupport::TestCase
  MIGRATION_PATH = Rails.root.join(
    "db/migrate/20260825210000_add_index_position_to_collections.rb"
  )

  test "forward migration preserves existing Collections as unindexed" do
    with_current_schema_database(existing_row: true) do |database_path|
      migrate(database_path)
      database = open_database(database_path)

      column = database.execute("PRAGMA table_info(collections)")
        .find { |candidate| candidate.fetch("name") == "index_position" }
      assert_equal "bigint", column.fetch("type")
      assert_equal 0, column.fetch("notnull")
      assert_nil column.fetch("dflt_value")
      assert_nil database.get_first_value(
        "SELECT index_position FROM collections WHERE id = 'existing'"
      )
    ensure
      database&.close
    end
  end

  test "forward migration gives a fresh database the same nullable column" do
    with_current_schema_database(existing_row: false) do |database_path|
      migrate(database_path)
      database = open_database(database_path)
      column = database.execute("PRAGMA table_info(collections)")
        .find { |candidate| candidate.fetch("name") == "index_position" }

      assert_equal "bigint", column.fetch("type")
      assert_equal 0, column.fetch("notnull")
      assert_nil column.fetch("dflt_value")
    ensure
      database&.close
    end
  end

  test "database constraint accepts only NULL or positive Index positions" do
    with_migrated_database do |database|
      insert_collection(database, id: "null-position", position: nil)
      insert_collection(database, id: "positive-position", position: 1)

      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "zero-position", position: 0)
      end
      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "negative-position", position: -1)
      end
    end
  end

  test "partial unique index applies only to kept non-NULL positions" do
    with_migrated_database do |database|
      insert_collection(database, id: "kept", position: 4)
      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "kept-duplicate", position: 4)
      end

      database.execute("DELETE FROM collections WHERE id = 'kept'")
      insert_collection(database, id: "deleted", position: 4,
        deleted_at: "2026-08-25 14:00:00")
      insert_collection(database, id: "kept-after-deleted", position: 4)
      insert_collection(database, id: "null-one", position: nil)
      insert_collection(database, id: "null-two", position: nil)

      index_sql = database.get_first_value(<<~SQL)
        SELECT sql FROM sqlite_master
        WHERE type = 'index' AND name = 'index_collections_on_user_id_and_index_position'
      SQL
      assert_match(/UNIQUE/, index_sql)
      assert_match(/deleted_at IS NULL AND index_position IS NOT NULL/, index_sql)
    end
  end

  private

  def with_migrated_database
    with_current_schema_database(existing_row: false) do |database_path|
      migrate(database_path)
      database = open_database(database_path)
      yield database
    ensure
      database&.close
    end
  end

  def with_current_schema_database(existing_row:)
    database_path = Rails.root.join(
      "tmp/collection_index_position_migration_#{Process.pid}_#{SecureRandom.hex(4)}.sqlite3"
    )
    database = SQLite3::Database.new(database_path.to_s)
    database.execute_batch <<~SQL
      CREATE TABLE collections (
        id varchar PRIMARY KEY,
        user_id integer NOT NULL,
        name varchar NOT NULL,
        hlc varchar,
        server_seq bigint,
        deleted_at datetime,
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL
      );
    SQL
    insert_collection(database, id: "existing", position: :column_absent) if existing_row
    database.close

    yield database_path
  ensure
    database&.close rescue nil
    FileUtils.rm_f(database_path) if database_path
  end

  def migrate(database_path)
    script = <<~RUBY
      require "active_record"
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV.fetch(0))
      require ARGV.fetch(1)
      AddIndexPositionToCollections.new.migrate(:up)
    RUBY
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      "-e",
      script,
      database_path.to_s,
      MIGRATION_PATH.to_s
    )

    assert status.success?, [ stdout, stderr ].join("\n")
  end

  def open_database(database_path)
    SQLite3::Database.new(database_path.to_s).tap { |database| database.results_as_hash = true }
  end

  def insert_collection(database, id:, position:, deleted_at: nil)
    values = [ id, 1, id, deleted_at, "2026-08-25 14:00:00", "2026-08-25 14:00:00" ]
    if position == :column_absent
      database.execute(<<~SQL, values)
        INSERT INTO collections (id, user_id, name, deleted_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
      SQL
    else
      database.execute(<<~SQL, [ *values, position ])
        INSERT INTO collections
          (id, user_id, name, deleted_at, created_at, updated_at, index_position)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      SQL
    end
  end
end
