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
end
