class CreateKarmastats < ActiveRecord::Migration
  def up
    create_table :karmastats do |t|
      t.integer :user_id
      t.integer :total
      t.integer :rank
      t.timestamp
    end
  end
end
