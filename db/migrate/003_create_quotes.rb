class CreatesPages < ActiveRecord::Migration
  def up
    create_table :quotes do |t|
      t.string :user_create
      t.string :user
      t.text :quote
      
      t.timestamp
    end
  end
end
