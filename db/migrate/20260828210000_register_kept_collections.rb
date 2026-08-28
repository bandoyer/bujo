class RegisterKeptCollections < ActiveRecord::Migration[8.1]
  # Registers every live Collection left hidden by the superseded creation
  # behavior, then prevents another live row from being hidden.
  def up
    backfill_kept_collections
    add_check_constraint :collections,
      "deleted_at IS NOT NULL OR index_position IS NOT NULL",
      name: "collections_kept_index_position_present"
  end

  # The prior distinction between intentionally and accidentally unindexed
  # rows cannot be recovered after the deterministic registration pass.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_kept_collections
    retained_maxima.each do |user_id, maximum|
      hidden_collection_ids(user_id).each.with_index(maximum + 1) do |id, position|
        execute <<~SQL.squish
          UPDATE collections
          SET index_position = #{connection.quote(position)}
          WHERE id = #{connection.quote(id)}
        SQL
      end
    end
  end

  def retained_maxima
    rows = select_all(<<~SQL.squish)
      SELECT user_id, COALESCE(MAX(index_position), 0) AS maximum_position
      FROM collections
      GROUP BY user_id
      ORDER BY user_id
    SQL
    rows.map do |row|
      [ row.fetch("user_id"), row.fetch("maximum_position").to_i ]
    end
  end

  def hidden_collection_ids(user_id)
    select_values <<~SQL.squish
      SELECT id
      FROM collections
      WHERE user_id = #{connection.quote(user_id)}
        AND deleted_at IS NULL
        AND index_position IS NULL
      ORDER BY created_at, id
    SQL
  end
end
