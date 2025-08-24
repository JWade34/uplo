class AddProcessingStartedAtToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :processing_started_at, :datetime
  end
end
