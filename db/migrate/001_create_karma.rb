class CreateKarma < ActiveRecord::Migration
  def up
    create_table :karma do |t|
      t.integer :grantor_id
      t.integer :recipient_id
      t.integer :amount

      t.timestamp
    end
  end
end
