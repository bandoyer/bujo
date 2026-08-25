require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "requires a name" do
    collection = Collection.new(user: users(:one), name: "   ")

    assert_not collection.valid?
    assert_includes collection.errors[:name], "can't be blank"
  end

  test "kept names are unique per user without regard to case" do
    existing = collections(:camping)
    duplicate = existing.user.collections.new(name: "camping trip")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "a deleted name can be recreated and another user can reuse it" do
    existing = collections(:camping)
    deleted_at = Time.zone.parse("2026-08-24 12:00:00")
    other_user = User.create!(email_address: "other@example.com", password: "password")

    existing.soft_delete!(at: deleted_at)
    replacement = existing.user.collections.create!(name: "CAMPING TRIP")
    reused = other_user.collections.create!(name: "Camping Trip")

    assert_equal deleted_at, existing.reload.deleted_at
    assert_not_equal existing.id, replacement.id
    assert_predicate reused, :persisted?
  end

  test "kept excludes soft-deleted rows without hiding them by default" do
    collection = collections(:camping)
    collection.soft_delete!(at: Time.zone.parse("2026-08-24 12:00:00"))

    assert_not_includes Collection.kept, collection
    assert_equal collection, Collection.find(collection.id)
  end

  test "generates UUIDv7 ids while preserving caller-supplied ids" do
    generated = users(:one).collections.create!(name: "Generated")
    supplied_id = "0198f3b9-0000-7000-8000-000000000099"
    supplied = users(:one).collections.create!(id: supplied_id, name: "Supplied")

    assert_uuid_v7 generated.id
    assert_equal supplied_id, supplied.id
  end

  test "normalizes Topics without changing case or internal whitespace" do
    collection = users(:one).collections.create!(name: "  Reading   List  ")

    assert_equal "Reading   List", collection.name
  end

  test "creation and ordinary updates cannot write an Index position" do
    assert_no_difference -> { Collection.count } do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        users(:one).collections.create!(name: "Authored rank", index_position: 3)
      end
      assert_includes error.record.errors.details[:index_position], error: :readonly
    end

    collection = collections(:camping)
    collection.update_column(:index_position, 3)

    assert_raises(ActiveRecord::RecordInvalid) { collection.update!(index_position: 7) }
    assert_equal 3, collection.reload.index_position

    collection.assign_attributes(index_position: 7)
    assert_not collection.save
    assert_includes collection.errors.details[:index_position], error: :readonly
    assert_equal 3, collection.reload.index_position

    collection.update!(name: "Renamed")
    assert_equal 3, collection.reload.index_position

    collection.soft_delete!(at: Time.zone.parse("2026-08-25 10:00:00"))
    assert_equal 3, collection.reload.index_position
  end

  test "creation starts unindexed without writing dormant sync fields" do
    collection = users(:one).collections.create!(name: "Unindexed")

    assert_nil collection.index_position
    assert_nil collection.hlc
    assert_nil collection.server_seq
  end

  test "registration walks append positions without compacting or reusing gaps" do
    camping = collections(:camping)

    assert_raises(Collection::LifecycleError) { camping.register! }
    assert_nil camping.reload.index_position

    create_collection_entry(camping)
    camping.register!
    assert_equal 1, camping.reload.index_position

    reading = create_filled_collection("Reading List")
    reading.register!
    assert_equal 2, reading.reload.index_position

    assert_raises(Collection::LifecycleError) { camping.register! }
    assert_equal 1, camping.reload.index_position

    camping.unindex!
    assert_nil camping.reload.index_position
    assert_equal 2, reading.reload.index_position

    assert_raises(Collection::LifecycleError) { camping.unindex! }
    camping.register!
    assert_equal 3, camping.reload.index_position

    reading.unindex!
    assert_nil reading.reload.index_position
    assert_equal 3, camping.reload.index_position

    packing = create_filled_collection("Packing")
    packing.register!
    assert_equal 4, packing.reload.index_position
  end

  test "registration allocation counts retained positions from soft-deleted sync rows" do
    sync_tombstone = users(:one).collections.create!(name: "Synced tombstone")
    sync_tombstone.update_columns(
      index_position: 8,
      deleted_at: Time.zone.parse("2026-08-25 11:00:00")
    )
    collection = create_filled_collection("After sync")

    collection.register!

    assert_equal 9, collection.reload.index_position,
      "a server-allocated position must not reuse a rank retained by a synced tombstone"
  end

  test "registration requires a kept resident not merely entry history" do
    collection = create_filled_collection("Tombstoned residents")
    collection.entries.each do |entry|
      entry.soft_delete!(at: Time.zone.parse("2026-08-25 12:45:00"))
    end

    assert_not collection.registrable?,
      "a Collection whose only entries are soft-deleted is not registrable"
    assert_raises(Collection::LifecycleError) { collection.register! }
    assert_nil collection.reload.index_position
  end

  test "registrable predicate agrees with empty indexed and deleted transitions" do
    collection = users(:one).collections.create!(name: "Predicate")
    assert_not collection.registrable?

    create_collection_entry(collection)
    assert_predicate collection, :registrable?

    collection.register!
    assert_not collection.reload.registrable?

    collection.unindex!
    collection.soft_delete!
    assert_not collection.reload.registrable?
  end

  test "unindex refuses a sync tombstone that retained its Index rank" do
    tombstone = users(:one).collections.create!(name: "Indexed tombstone")
    tombstone.update_columns(
      index_position: 6,
      deleted_at: Time.zone.parse("2026-08-25 11:30:00")
    )

    assert_raises(Collection::LifecycleError) { tombstone.unindex! }
    assert_equal 6, tombstone.reload.index_position,
      "unindex must not clear a rank on a Collection that is no longer kept"
  end

  test "unindex clears only the position and refuses repetition" do
    collection = create_filled_collection("Stable")
    collection.update!(hlc: "dormant", server_seq: 41)
    collection.register!
    entry_ids = collection.entries.ids

    collection.unindex!

    assert_nil collection.reload.index_position
    assert_equal "Stable", collection.name
    assert_equal "dormant", collection.hlc
    assert_equal 41, collection.server_seq
    assert_equal entry_ids, collection.entries.ids
    assert_raises(Collection::LifecycleError) { collection.unindex! }
  end

  test "guarded deletion tombstones only a kept never-used Collection" do
    collection = users(:one).collections.create!(name: "Never used")
    deleted_at = Time.zone.parse("2026-08-25 12:00:00")

    assert_predicate collection, :deletable?
    collection.soft_delete_if_unused!(at: deleted_at)

    assert_equal deleted_at, collection.reload.deleted_at
    assert_nil collection.index_position
    assert_nil collection.hlc
    assert_nil collection.server_seq
    assert_not collection.deletable?
    assert_raises(Collection::LifecycleError) { collection.soft_delete_if_unused! }
  end

  test "guarded deletion refuses every Collection with entry history without cascades" do
    kept_collection = create_filled_collection("Kept history")
    kept_entry = kept_collection.entries.first
    deleted_collection = create_filled_collection("Deleted history")
    deleted_entry = deleted_collection.entries.first
    deleted_entry.soft_delete!(at: Time.zone.parse("2026-08-25 12:30:00"))

    [ kept_collection, deleted_collection ].each do |collection|
      assert_not collection.deletable?
      assert_raises(Collection::LifecycleError) { collection.soft_delete_if_unused! }
      assert_nil collection.reload.deleted_at
    end

    assert_nil kept_entry.reload.deleted_at
    assert_not_nil deleted_entry.reload.deleted_at
    assert_equal kept_collection, kept_entry.collection
    assert_equal deleted_collection, deleted_entry.collection
  end

  test "Index relation is ordered manually and excludes unindexed deleted and foreign rows" do
    first = create_filled_collection("First")
    second = create_filled_collection("Second")
    unindexed = users(:one).collections.create!(name: "Unindexed")
    deleted = create_filled_collection("Deleted")
    foreign = users(:two).collections.create!(name: "Foreign")
    first.update_column(:index_position, 2)
    second.update_column(:index_position, 5)
    deleted.update_columns(index_position: 3, deleted_at: Time.zone.parse("2026-08-25 13:00:00"))
    foreign.update_column(:index_position, 1)

    relation = users(:one).collections.in_index_order

    assert_equal [ first, second ], relation.to_a
    assert_not_includes relation, unindexed
    assert_not_includes relation, deleted
    assert_not_includes relation, foreign
    # A behavioral id tie cannot be constructed because the kept-position
    # unique index forbids it, so pin the defensive SQL tiebreaker directly.
    assert_match(/ORDER BY .*index_position.*ASC, .*id.*ASC/, relation.to_sql)
  end

  test "exact Topic lookup trims and compares equality within the caller relation" do
    camping = collections(:camping)
    foreign = users(:two).collections.create!(name: "Camping Trip")
    relation = users(:one).collections.kept

    assert_equal [ camping ], relation.with_exact_topic("camping trip").to_a
    assert_equal [ camping ], relation.with_exact_topic("  Camping Trip  ").to_a
    assert_empty relation.with_exact_topic("Camping")
    assert_empty relation.with_exact_topic("Trip")
    assert_empty relation.with_exact_topic("Camping Trip 2")
    assert_empty relation.with_exact_topic("")
    assert_not_includes relation.with_exact_topic("Camping Trip"), foreign
    assert_kind_of ActiveRecord::Relation, relation.with_exact_topic("Camping Trip")
  end

  private

  def create_filled_collection(name)
    collection = users(:one).collections.create!(name: name)
    create_collection_entry(collection)
    collection
  end

  def create_collection_entry(collection, **overrides)
    Entry.create!({
      user: collection.user,
      collection: collection,
      kind: "task",
      state: "open",
      text: "Collection content",
      priority: false,
      tags: [],
      page_kind: "collection",
      page_on: nil
    }.merge(overrides))
  end
end
