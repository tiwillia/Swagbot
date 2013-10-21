class CreateKarmastats < ActiveRecord::Migration
  def change
    create_table :karmastats do |t|
      t.integer :user_id
      t.integer :total
      t.integer :rank

      t.timestamps
    end
  end
end
