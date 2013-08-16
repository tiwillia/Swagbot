class CreateDefinitions < ActiveRecord::Migration
  def up
    create_table :definitions do |t|
      t.integer :recorder_id
      t.string :word
      t.text :definition

      t.timestamp
    end
  end
end
