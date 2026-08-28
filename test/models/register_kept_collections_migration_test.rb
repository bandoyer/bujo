require "test_helper"
require "open3"
require "rbconfig"
require "sqlite3"

# Proves the one-time correction without loading the current Collection model.
class RegisterKeptCollectionsMigrationTest < ActiveSupport::TestCase
  MIGRATION_PATH = Rails.root.join(
    "db/migrate/20260828210000_register_kept_collections.rb"
  )

  test "forward appends kept NULL rows deterministically per user and changes nothing else" do
    with_prior_schema_database do |database_path|
      seed_transition_rows(database_path)
      before = snapshot(database_path)

      migrate(database_path, :up)

      after = snapshot(database_path)
      assert_equal({
        "u1-ranked" => 2,
        "u1-ranked-tombstone" => 9,
        "u1-null-z" => 10,
        "u1-null-a" => 11,
        "u1-null-b" => 12,
        "u1-null-tombstone" => nil,
        "u2-ranked" => 3,
        "u2-null" => 4,
        "u3-null" => 1
      }, after.to_h { |row| [ row.fetch("id"), row.fetch("index_position") ] })

      before_by_id = before.index_by { |row| row.fetch("id") }
      after.each do |row|
        assert_equal before_by_id.fetch(row.fetch("id")).except("index_position"),
          row.except("index_position")
      end
      assert_equal [ [ "entry-1", "u1-null-a", "resident", "2026-08-20 10:00:00" ] ],
        entries_snapshot(database_path)
    end
  end

  test "final checks accept tombstone shapes and reject hidden or nonpositive live rows" do
    with_prior_schema_database do |database_path|
      migrate(database_path, :up)
      database = open_database(database_path)

      insert_collection(database, id: "kept", user_id: 1, position: 1)
      insert_collection(database, id: "null-tombstone", user_id: 1, position: nil,
        deleted_at: "2026-08-25 14:00:00")
      insert_collection(database, id: "ranked-tombstone", user_id: 1, position: 1,
        deleted_at: "2026-08-25 14:00:00")

      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "hidden", user_id: 1, position: nil)
      end
      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "zero", user_id: 1, position: 0)
      end
      assert_raises(SQLite3::ConstraintException) do
        insert_collection(database, id: "duplicate", user_id: 1, position: 1)
      end

      checks = database.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name = 'collections'")
        .first.fetch("sql")
      assert_includes checks, "collections_index_position_positive"
      assert_includes checks, "collections_kept_index_position_present"
    ensure
      database&.close
    end
  end

  test "down is irreversible" do
    with_prior_schema_database do |database_path|
      migrate(database_path, :up)
      _stdout, stderr, status = run_migration(database_path, :down)

      assert_not status.success?
      assert_includes stderr, "ActiveRecord::IrreversibleMigration"
    end
  end

  test "fresh schema exposes the same checks and kept partial unique index" do
    check_names = ActiveRecord::Base.connection.check_constraints(:collections).map(&:name)
    index = ActiveRecord::Base.connection.indexes(:collections)
      .find { |candidate| candidate.name == "index_collections_on_user_id_and_index_position" }

    assert_includes check_names, "collections_index_position_positive"
    assert_includes check_names, "collections_kept_index_position_present"
    assert_predicate index, :unique
    assert_equal "deleted_at IS NULL AND index_position IS NOT NULL", index.where
  end

  private

  def with_prior_schema_database
    database_path = Rails.root.join(
      "tmp/register_kept_collections_#{Process.pid}_#{SecureRandom.hex(4)}.sqlite3"
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
        updated_at datetime NOT NULL,
        index_position bigint,
        CONSTRAINT collections_index_position_positive
          CHECK (index_position IS NULL OR index_position > 0)
      );
      CREATE UNIQUE INDEX index_collections_on_user_id_and_index_position
        ON collections (user_id, index_position)
        WHERE deleted_at IS NULL AND index_position IS NOT NULL;
      CREATE TABLE entries (
        id varchar PRIMARY KEY,
        collection_id varchar,
        text varchar NOT NULL,
        updated_at datetime NOT NULL
      );
    SQL
    database.close

    yield database_path
  ensure
    database&.close rescue nil
    FileUtils.rm_f(database_path) if database_path
  end

  def seed_transition_rows(database_path)
    database = open_database(database_path)
    insert_collection(database, id: "u1-ranked", user_id: 1, position: 2)
    insert_collection(database, id: "u1-ranked-tombstone", user_id: 1, position: 9,
      deleted_at: "2026-08-24 12:00:00")
    insert_collection(database, id: "u1-null-b", user_id: 1, position: nil,
      created_at: "2026-08-25 10:00:00")
    insert_collection(database, id: "u1-null-a", user_id: 1, position: nil,
      created_at: "2026-08-25 10:00:00")
    # Later id, earlier created_at: append order is created_at then id, not id alone.
    insert_collection(database, id: "u1-null-z", user_id: 1, position: nil,
      created_at: "2026-08-25 09:00:00")
    insert_collection(database, id: "u1-null-tombstone", user_id: 1, position: nil,
      deleted_at: "2026-08-24 13:00:00")
    insert_collection(database, id: "u2-ranked", user_id: 2, position: 3)
    insert_collection(database, id: "u2-null", user_id: 2, position: nil)
    insert_collection(database, id: "u3-null", user_id: 3, position: nil)
    database.execute(
      "INSERT INTO entries (id, collection_id, text, updated_at) VALUES (?, ?, ?, ?)",
      [ "entry-1", "u1-null-a", "resident", "2026-08-20 10:00:00" ]
    )
  ensure
    database&.close
  end

  def insert_collection(database, id:, user_id:, position:, deleted_at: nil,
    created_at: "2026-08-25 14:00:00")
    values = [ id, user_id, id, "clock", 41, deleted_at, created_at,
      "2026-08-25 15:00:00", position ]
    database.execute(<<~SQL, values)
      INSERT INTO collections
        (id, user_id, name, hlc, server_seq, deleted_at, created_at, updated_at, index_position)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    SQL
  end

  def snapshot(database_path)
    database = open_database(database_path)
    database.execute("SELECT * FROM collections ORDER BY id")
  ensure
    database&.close
  end

  def entries_snapshot(database_path)
    database = open_database(database_path)
    database.execute("SELECT id, collection_id, text, updated_at FROM entries ORDER BY id").map(&:values)
  ensure
    database&.close
  end

  def migrate(database_path, direction)
    stdout, stderr, status = run_migration(database_path, direction)
    assert status.success?, [ stdout, stderr ].join("\n")
  end

  def run_migration(database_path, direction)
    script = <<~RUBY
      require "active_record"
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV.fetch(0))
      require ARGV.fetch(1)
      RegisterKeptCollections.new.migrate(ARGV.fetch(2).to_sym)
    RUBY
    Open3.capture3(RbConfig.ruby, "-e", script, database_path.to_s,
      MIGRATION_PATH.to_s, direction.to_s)
  end

  def open_database(database_path)
    SQLite3::Database.new(database_path.to_s).tap { |database| database.results_as_hash = true }
  end
end
