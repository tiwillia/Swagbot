class CreateBotConfigs < ActiveRecord::Migration
  def change
    create_table :bot_configs do |t|
      t.integer :bot_id
      t.integer :karma_timeout, :default => 5
      t.boolean :echo_all_definitions, :default => true

      t.timestamps
    end
  end
end
