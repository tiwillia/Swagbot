class CreatesDefinitions < ActiveRecord::Migration
  def up
    create_table :definitions do |t|
      t.text :word
      t.text :definition
      t.string :user

      t.timestamp
    end
  end
end
