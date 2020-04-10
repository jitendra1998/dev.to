class CreateClassifiedListingCategories < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    create_table :classified_listing_categories do |t|
      t.string :name, null: false
      t.integer :cost, null: false
      t.string :rules, null: false

      t.timestamps
    end
    add_index(:classified_listing_categories, :name, unique: true, algorithm: :concurrently)
  end
end
