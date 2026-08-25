class AddPageResidencyToEntries < ActiveRecord::Migration[8.1]
  PAGE_KINDS = %w[daily monthly_calendar monthly_tasks future collection].freeze

  def up
    add_column :entries, :page_kind, :string
    change_column_null :entries, :logged_on, true
    build_root_map
    normalize_tree_placement
    drop_root_map

    rename_column :entries, :logged_on, :page_on
    change_column_null :entries, :page_kind, false
    add_check_constraint :entries,
      "page_kind IN (#{PAGE_KINDS.map { |kind| connection.quote(kind) }.join(', ')})",
      name: "entries_page_kind_allowed"

    remove_index :entries, column: %i[user_id page_on]
    add_index :entries, %i[user_id page_kind page_on]
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Future and Collection residency cannot be converted back to a required logged_on date"
  end

  private

  # A temporary root map lets every descendant inherit one authoritative
  # placement even when legacy children contain contradictory dates or
  # Collection ids.
  def build_root_map
    execute <<~SQL
      CREATE TEMPORARY TABLE entry_residency_roots AS
      WITH RECURSIVE entry_tree(id, root_id) AS (
        SELECT id, id FROM entries WHERE parent_id IS NULL
        UNION ALL
        SELECT child.id, entry_tree.root_id
        FROM entries child
        JOIN entry_tree ON child.parent_id = entry_tree.id
      )
      SELECT entry_tree.id,
             roots.collection_id AS root_collection_id,
             roots.logged_on AS root_logged_on
      FROM entry_tree
      JOIN entries roots ON roots.id = entry_tree.root_id
    SQL
  end

  def normalize_tree_placement
    execute <<~SQL
      UPDATE entries
      SET page_kind = CASE
            WHEN (SELECT root_collection_id FROM entry_residency_roots WHERE id = entries.id) IS NULL
              THEN 'daily'
            ELSE 'collection'
          END,
          logged_on = CASE
            WHEN (SELECT root_collection_id FROM entry_residency_roots WHERE id = entries.id) IS NULL
              THEN (SELECT root_logged_on FROM entry_residency_roots WHERE id = entries.id)
            ELSE NULL
          END,
          collection_id = (
            SELECT root_collection_id FROM entry_residency_roots WHERE id = entries.id
          )
    SQL
  end

  def drop_root_map
    execute "DROP TABLE entry_residency_roots"
  end
end
