class AddIndexPositionToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :index_position, :bigint
    add_index :collections,
      [ :user_id, :index_position ],
      unique: true,
      where: "deleted_at IS NULL AND index_position IS NOT NULL"
    add_check_constraint :collections,
      "index_position IS NULL OR index_position > 0",
      name: "collections_index_position_positive"
  end
end
