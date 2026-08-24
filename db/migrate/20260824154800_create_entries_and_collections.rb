class CreateEntriesAndCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections, id: :string do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :hlc
      t.bigint :server_seq
      t.datetime :deleted_at

      t.timestamps
    end

    create_table :entries, id: :string do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :state
      t.text :text, null: false
      t.boolean :priority, null: false, default: false
      t.json :tags, null: false, default: []
      t.date :logged_on, null: false
      t.date :occurs_on
      t.string :time_of_day
      t.references :collection, type: :string, foreign_key: true
      t.references :parent, type: :string, foreign_key: { to_table: :entries }
      t.references :migrated_from,
        type: :string,
        foreign_key: { to_table: :entries },
        index: { unique: true }
      t.string :hlc
      t.bigint :server_seq
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :collections, :server_seq
    add_index :entries, [ :user_id, :logged_on ]
    add_index :entries, [ :user_id, :occurs_on ]
    add_index :entries, [ :user_id, :state ]
    add_index :entries, :server_seq
  end
end
