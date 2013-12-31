class CreateKarmaEntries < ActiveRecord::Migration
  def change
    create_table :karma_entries do |t|
      t.integer :grantor_id
      t.integer :recipient_id
      t.integer :amount

      t.timestamps
    end
  end
end
