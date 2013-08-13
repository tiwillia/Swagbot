class CreatesDefinitions < ActiveRecord::Migration
  def change
    create_table :definitions do |t|
      t.text :word
      t.text :definition
      t.string :user

      t.timestamp
    end
  end
end
