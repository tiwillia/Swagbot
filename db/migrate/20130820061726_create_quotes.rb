class CreateQuotes < ActiveRecord::Migration
  def change
    create_table :quotes do |t|
      t.integer :recorder_id
      t.integer :quotee_id
      t.text :quote

      t.timestamps
    end
  end
end
