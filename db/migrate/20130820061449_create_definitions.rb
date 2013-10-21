class CreateDefinitions < ActiveRecord::Migration
  def change
    create_table :definitions do |t|
      t.integer :recorder_id
      t.text :word
      t.text :definition

      t.timestamps
    end
  end
end
