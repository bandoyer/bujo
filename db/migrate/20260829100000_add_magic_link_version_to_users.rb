# Adds the non-sync generation used to invalidate outstanding sign-in links.
class AddMagicLinkVersionToUsers < ActiveRecord::Migration[8.1]
  # Backfills zero and prevents invalid negative generations at the database edge.
  def change
    add_column :users, :magic_link_version, :integer, null: false, default: 0
    add_check_constraint :users, "magic_link_version >= 0",
      name: "users_magic_link_version_nonnegative"
  end
end
