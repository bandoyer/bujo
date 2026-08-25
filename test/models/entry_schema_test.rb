require "test_helper"

# Pins the sync-sensitive shape of entries and collections.
class EntrySchemaTest < ActiveSupport::TestCase
  test "uses string primary keys and the existing integer user key" do
    assert_equal :string, Entry.type_for_attribute("id").type
    assert_equal :string, Collection.type_for_attribute("id").type
    assert_equal :integer, Entry.type_for_attribute("user_id").type
    assert_equal :integer, Collection.type_for_attribute("user_id").type
  end

  test "declares the entry columns and defaults" do
    columns = Entry.columns_hash

    assert_not columns.fetch("user_id").null
    assert_not columns.fetch("kind").null
    assert columns.fetch("state").null
    assert_not columns.fetch("text").null
    assert_not columns.fetch("priority").null
    assert_not columns.fetch("priority").default
    assert_not columns.fetch("tags").null
    assert_equal [], Entry.type_for_attribute("tags").deserialize(columns.fetch("tags").default)
    assert_not columns.fetch("page_kind").null
    assert_nil columns.fetch("page_kind").default
    assert columns.fetch("page_on").null
    assert columns.fetch("occurs_on").null
    assert columns.fetch("time_of_day").null
    assert_equal :string, columns.fetch("collection_id").type
    assert_equal :string, columns.fetch("parent_id").type
    assert_equal :string, columns.fetch("migrated_from_id").type
    assert columns.fetch("hlc").null
    assert columns.fetch("server_seq").null
    assert columns.fetch("deleted_at").null
  end

  test "declares the collection columns without a kind" do
    columns = Collection.columns_hash

    assert_not columns.fetch("name").null
    assert columns.fetch("hlc").null
    assert columns.fetch("server_seq").null
    assert columns.fetch("deleted_at").null
    assert_not_includes columns, "kind"
  end

  test "indexes logs, relationships, sync cursors, and the migration chain" do
    entry_indexes = ActiveRecord::Base.connection.indexes(:entries)
    collection_indexes = ActiveRecord::Base.connection.indexes(:collections)

    assert_index entry_indexes, %w[user_id page_kind page_on]
    assert_index entry_indexes, %w[user_id occurs_on]
    assert_index entry_indexes, %w[user_id state]
    assert_index entry_indexes, %w[collection_id]
    assert_index entry_indexes, %w[parent_id]
    assert_index entry_indexes, %w[server_seq]
    assert_index entry_indexes, %w[migrated_from_id], unique: true
    assert_index collection_indexes, %w[server_seq]
  end

  test "enforces every declared foreign key" do
    entry_foreign_keys = ActiveRecord::Base.connection.foreign_keys(:entries)
    collection_foreign_keys = ActiveRecord::Base.connection.foreign_keys(:collections)

    assert_foreign_key entry_foreign_keys, "users", "user_id"
    assert_foreign_key entry_foreign_keys, "collections", "collection_id"
    assert_foreign_key entry_foreign_keys, "entries", "parent_id"
    assert_foreign_key entry_foreign_keys, "entries", "migrated_from_id"
    assert_foreign_key collection_foreign_keys, "users", "user_id"
  end

  private

  def assert_index(indexes, columns, unique: false)
    index = indexes.find { |candidate| candidate.columns == columns }

    assert index, "Expected an index on #{columns.join(', ')}"
    assert_equal unique, index.unique
  end

  def assert_foreign_key(foreign_keys, table, column)
    assert foreign_keys.any? { |key| key.to_table == table && key.column == column },
      "Expected #{column} to reference #{table}"
  end
end
