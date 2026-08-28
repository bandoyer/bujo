require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  class RacingCollection < Collection
    class << self
      attr_accessor :save_attempts, :fail_until
    end

    private

    def save_at_index_position!(position)
      self.class.save_attempts += 1
      if self.class.save_attempts <= self.class.fail_until
        raise ActiveRecord::RecordNotUnique, "simulated append race"
      end

      super
    end
  end

  test "atomic creation normalizes a Topic and allocates the first retained position" do
    collection = Collection.create_for(user: users(:two), topic: "  Reading   List  ")

    assert_predicate collection, :persisted?
    assert_equal "Reading   List", collection.name
    assert_equal 1, collection.index_position
    assert_nil collection.hlc
    assert_nil collection.server_seq
  end

  test "atomic creation appends after kept and deleted retained ranks per user" do
    owner = users(:one)
    collections(:camping).update_column(:index_position, 2)
    tombstone = Collection.create_for(user: owner, topic: "Old Topic")
    tombstone.update_columns(index_position: 9, deleted_at: Time.zone.parse("2026-08-25 11:00:00"))
    foreign = Collection.create_for(user: users(:two), topic: "Foreign")
    foreign.update_column(:index_position, 3)

    appended = Collection.create_for(user: owner, topic: "Packing")
    foreign_appended = Collection.create_for(user: users(:two), topic: "Other")

    assert_equal 10, appended.index_position
    assert_equal 4, foreign_appended.index_position
  end

  test "blank and duplicate Topics persist no row and consume no position" do
    owner = users(:one)
    before = owner.collections.order(:id).pluck(:id, :index_position)

    blank = Collection.create_for(user: owner, topic: "   ")
    duplicate = Collection.create_for(user: owner, topic: "camping trip")
    appended = Collection.create_for(user: owner, topic: "Packing")

    assert_not_predicate blank, :persisted?
    assert_includes blank.errors[:name], "can't be blank"
    assert_not_predicate duplicate, :persisted?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_equal before, owner.collections.where.not(id: appended.id).order(:id).pluck(:id, :index_position)
    assert_equal 2, appended.index_position
  end

  test "atomic creation generates UUIDv7 ids and preserves a supplied UUIDv7 id" do
    generated = Collection.create_for(user: users(:one), topic: "Generated")
    supplied_id = "0198f3b9-0000-7000-8000-000000000099"
    supplied = Collection.create_for(user: users(:one), topic: "Supplied", id: supplied_id)

    assert_uuid_v7 generated.id
    assert_equal supplied_id, supplied.id
  end

  test "atomic creation retries a position uniqueness race without exposing it" do
    RacingCollection.save_attempts = 0
    RacingCollection.fail_until = 1

    collection = RacingCollection.create_for(user: users(:one), topic: "Retried")

    assert_predicate collection, :persisted?
    assert_equal 2, RacingCollection.save_attempts
    assert_equal 2, collection.index_position
  end

  test "atomic creation keeps retrying through two uniqueness races" do
    RacingCollection.save_attempts = 0
    RacingCollection.fail_until = 2

    collection = RacingCollection.create_for(user: users(:one), topic: "Retried twice")

    assert_predicate collection, :persisted?
    assert_equal 3, RacingCollection.save_attempts
    assert_equal 2, collection.index_position
  end

  test "atomic creation refuses after bounded uniqueness races without a raw unique error" do
    RacingCollection.save_attempts = 0
    RacingCollection.fail_until = Collection::CREATION_ATTEMPTS

    collection = nil
    assert_no_difference -> { Collection.count } do
      collection = RacingCollection.create_for(user: users(:one), topic: "Exhausted")
    end

    assert_not_predicate collection, :persisted?
    assert_includes collection.errors[:base], "Collection could not be created"
    assert_equal Collection::CREATION_ATTEMPTS, RacingCollection.save_attempts
  end

  test "ordinary creation and assignment cannot author a position or a kept hidden row" do
    assert_no_difference -> { Collection.count } do
      hidden = users(:one).collections.new(name: "Hidden")
      assert_not hidden.save
      assert_includes hidden.errors.details[:index_position], error: :blank
    end

    assert_no_difference -> { Collection.count } do
      authored = users(:one).collections.new(name: "Authored", index_position: 12)
      assert_not authored.save
      assert_includes authored.errors.details[:index_position], error: :readonly
    end

    collection = collections(:camping)
    original_position = collection.index_position
    collection.assign_attributes(index_position: original_position + 10)

    assert_not collection.save
    assert_includes collection.errors.details[:index_position], error: :readonly
    assert_equal original_position, collection.reload.index_position
  end

  test "tombstones may retain or omit a position" do
    retained = Collection.create_for(user: users(:one), topic: "Retained")
    retained.soft_delete_if_unused!
    omitted = users(:one).collections.new(name: "Old hidden tombstone", deleted_at: Time.current)

    assert_predicate retained, :valid?
    assert_predicate omitted, :valid?
    assert omitted.save
  end

  test "rename and guarded deletion preserve the permanent position" do
    collection = Collection.create_for(user: users(:one), topic: "Never used")
    position = collection.index_position

    collection.update!(name: "Renamed")
    assert_equal position, collection.reload.index_position

    collection.soft_delete_if_unused!(at: Time.zone.parse("2026-08-25 12:00:00"))
    assert_equal position, collection.reload.index_position
  end

  test "guarded deletion refuses every Collection with entry history without cascades" do
    collection = create_filled_collection("Kept history")
    entry = collection.entries.first

    assert_not collection.deletable?
    assert_raises(Collection::LifecycleError) { collection.soft_delete_if_unused! }
    assert_nil collection.reload.deleted_at
    assert_nil entry.reload.deleted_at
  end

  test "Index relation contains every kept owner Collection in append order" do
    owner = users(:one)
    first = collections(:camping)
    second = Collection.create_for(user: owner, topic: "Second")
    deleted = Collection.create_for(user: owner, topic: "Deleted")
    foreign = Collection.create_for(user: users(:two), topic: "Foreign")
    deleted.soft_delete_if_unused!

    relation = owner.collections.in_index_order

    assert_equal [ first, second ], relation.to_a
    assert_not_includes relation, deleted
    assert_not_includes relation, foreign
    assert_match(/ORDER BY .*index_position.*ASC, .*id.*ASC/, relation.to_sql)
  end

  test "exact Topic lookup remains scoped, trimmed, and case insensitive" do
    camping = collections(:camping)
    foreign = Collection.create_for(user: users(:two), topic: "Camping Trip")
    relation = users(:one).collections.kept

    assert_equal [ camping ], relation.with_exact_topic("  camping trip  ").to_a
    assert_empty relation.with_exact_topic("Camping")
    assert_not_includes relation.with_exact_topic("Camping Trip"), foreign
    assert_kind_of ActiveRecord::Relation, relation.with_exact_topic("Camping Trip")
  end

  private

  def create_filled_collection(topic)
    collection = Collection.create_for(user: users(:one), topic: topic)
    collection.entries.create!(
      user: collection.user,
      kind: "task",
      state: "open",
      text: "Collection content",
      priority: false,
      tags: [],
      page_kind: "collection",
      page_on: nil
    )
    collection
  end
end
