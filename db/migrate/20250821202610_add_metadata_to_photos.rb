class AddMetadataToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :metadata, :text
  end
end
