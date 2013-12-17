class AddBotIdToDefinitions < ActiveRecord::Migration
  def change
    add_column :definitions, :bot_id, :integer
  end
end
