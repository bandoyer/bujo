class AddInspirationToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :inspiration, :boolean, default: false, null: false
  end
end
