class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :filename
      t.string :content_type
      t.integer :file_size
      t.boolean :processed, default: false

      t.timestamps
    end
    
    add_index :photos, [:user_id, :created_at]
    add_index :photos, :processed
  end
end
