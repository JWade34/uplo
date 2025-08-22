class CreateCaptions < ActiveRecord::Migration[8.0]
  def change
    create_table :captions do |t|
      t.references :photo, null: false, foreign_key: true
      t.text :content
      t.string :style
      t.datetime :generated_at

      t.timestamps
    end
  end
end
