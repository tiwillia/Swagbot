class CreateQuotes < ActiveRecord::Migration
  def up
    create_table :quotes do |t|
      t.integer :recorder_id
      t.integer :quotee_id
      t.text :quote
      
      t.timestamp
    end
  end
end
