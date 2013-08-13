class CreatesKarma < ActiveRecord::Migration
  def change
    create_table :karma do |t|
      t.string :user
      t.integer :amount

      t.timestamp
    end
  end
end
