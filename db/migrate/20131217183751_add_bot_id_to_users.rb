class AddBotIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :bot_id, :integer
  end
end
